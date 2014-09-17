# ************************************************************************* 
# Copyright (c) 2014, SUSE LLC
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 
# 3. Neither the name of SUSE LLC nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# ************************************************************************* 

# ------------------------
# This package defines how our web server handles the request-response 
# cycle. All the "heavy lifting" is done by Web::Machine and Plack.
# ------------------------

package App::Dochazka::REST::Resource;

use strict;
use warnings;

use App::CELL qw( $CELL $log $meta $site );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch;
use App::Dochazka::REST::Dispatch::Employee;
use App::Dochazka::REST::Dispatch::Privhistory;
use App::Dochazka::REST::Dispatch::ACL qw( check_acl );
use App::Dochazka::REST::LDAP;
use App::Dochazka::REST::Model::Employee qw( nick_exists );
use App::Dochazka::REST::Util qw( deep_copy );
use Carp;
use Data::Dumper;
use Data::Structure::Util qw( unbless );
use Encode qw( decode_utf8 );
use JSON;
use Params::Validate qw(:all);
use Path::Router;
use Plack::Session;
use Scalar::Util qw( blessed );
use Try::Tiny;
use Web::Machine::Util qw( create_header );

# methods/attributes not defined in this module will be inherited from:
use parent 'Web::Machine::Resource';


=head1 NAME

App::Dochazka::REST::Resource - HTTP request/response cycle




=head1 VERSION

Version 0.169

=cut

our $VERSION = '0.169';





=head1 SYNOPSIS

In PSGI file:

    use Web::Machine;

    Web::Machine->new(
        resource => 'App::Dochazka::REST::Resource',
    )->to_app;




=head1 DESCRIPTION

This is where we override the default versions of various methods defined by
our "highway to H.A.T.E.O.S.": L<Web::Machine>. (Methods not defined in this
module will be inherited from L<Web::Machine::Resource>.)

Do note, however, that none of the routines in this module are called by
L<App::Dochazka::REST>. 

=cut




=head1 PACKAGE VARIABLES

=cut

# a package variable to streamline calls to the JSON module
my $JSON = JSON->new->allow_nonref->utf8->pretty;
# a package variable to store Path::Router instance for GET requests
my $router_get;
# a package variable to store Path::Router instance for POST requests
my $router_post;
# a package variable to store Path::Router instance for PUT requests
my $router_put;


=head1 METHODS


=head2 service_available

This is the first method called on every incoming request.

=cut

sub service_available {
    my $self = shift;
    my $path = decode_utf8( $self->request->path_info );
    $log->info( "Incoming " . $self->request->method . " request for $path" );
    $self->{'context'} = { 'path' => $path };
    return 1;
}


=head2 content_types_provided

L<Web::Machine> calls this routine to determine how to generate the response
body for GET requests. It is not called for PUT requests.

=cut
 
sub content_types_provided { [
    { 'text/html' => '_render_response_html' },
    { 'application/json' => '_render_response_json' },
] }


=head3 _render_response_html

Normally, clients will communicate with the server via
'_render_response_json', but humans need HTML. This method takes the
server's JSON response and wraps it up in a nice package.

=cut

sub _render_response_html { 
    my ( $self ) = @_;
    
    my $msgobj = $CELL->msg( 
        'DOCHAZKA_REST_HTML', 
        $VERSION, 
        $self->_make_json,
        App::Dochazka::REST::dbh->status,
    );
    $msgobj
        ? $msgobj->text
        : '<html><body><h1>Internal Error</h1><p>See Resource.pm->_render_response_html</p></body></html>';
}



=head3 _render_response_json

Encode the context as a JSON string. Wrapper for '_make_json', which is also
used in '_render_response_html'.

=cut

sub _render_response_json { ( shift )->_make_json; }



=head2 content_types_accepted

L<Web::Machine> calls this routine to determine how to handle the request
body (e.g. in PUT requests).

=cut
 
sub content_types_accepted { [
    { 'application/json' => '_handle_request_json' },
] }


=head3 _handle_request_json

PUT requests may contain a request body. This is the "handler
function" where we process those requests.

=cut

sub _handle_request_json {
    my $self = shift;
    $self->response->header('Content-Type' => 'application/json' );
    $self->response->body( $self->_make_json );
    return 1;
}


=head2 charsets_provided

This method causes L<Web::Machine> to encode the response body in UTF-8. 

=cut

sub charsets_provided { [ 'utf-8' ]; }



=head2 default_charset

Really use UTF-8 all the time.

=cut

sub default_charset { 'utf-8'; }



=head2 allowed_methods

Determines which HTTP methods we recognize.

=cut

sub allowed_methods { return [ 'GET', 'POST', 'PUT', ]; }



=head2 uri_too_long

Is the URI too long?

=cut

sub uri_too_long {
    my ( $self, $uri ) = @_;

    return ( length $uri > $site->DOCHAZKA_URI_MAX_LENGTH )
        ? 1
        : 0;
}


=head2 is_authorized

Authentication method.

Authenticate the originator of the request, using HTTP Basic Authentication.
Upon successful authentication, check that the user (employee) exists in 
the database (create if necessary) and retrieve her EID. Push the EID and
current privilege level onto the context.

=cut

sub is_authorized {
    my ( $self, $auth_header ) = @_;
    
    if ( ! $meta->META_DOCHAZKA_UNIT_TESTING ) {
        return 1 if $self->_validate_session;
    }
    if ( $auth_header ) {
        my $username = $auth_header->username;
        my $password = $auth_header->password;
        my $auth_status = _authenticate( $username, $password );
        if ( $auth_status->ok ) {
            my $emp = $auth_status->payload;
            $self->_push_onto_context( { current => $emp->expurgate, } );
            $self->_init_session( $emp ) unless $meta->META_DOCHAZKA_UNIT_TESTING;
            return 1;
        }
    }
    return create_header(
        'WWWAuthenticate' => [ 
            'Basic' => ( 
                realm => $site->DOCHAZKA_BASIC_AUTH_REALM 
            ) 
        ]
    ); 
}


=head3 _init_session

Initialize the session. Takes an employee object.

=cut

sub _init_session {
    my $self = shift;
    my ( $emp ) = validate_pos( @_, { type => HASHREF, can => 'eid' } );
    my $session = Plack::Session->new( $self->request->{'env'} );
    $session->set( 'eid', $emp->eid );
    $session->set( 'ip_addr', $self->request->{'env'}->{'REMOTE_ADDR'} );
    $session->set( 'last_seen', time );
    return;
}


=head3 _validate_session

Validate the session

=cut

sub _validate_session {
    my ( $self ) = @_;

    my $r = $self->request;
    my $session = Plack::Session->new( $r->{'env'} );
    my $remote_addr = $$r{'env'}{'REMOTE_ADDR'};

    $self->_push_onto_context( { 'session' => $session->dump  } );
    $self->_push_onto_context( { 'session_id' => $session->id } );
    $log->debug( "Session ID is " . $session->id );
    #$log->debug( "Remote address is " . $remote_addr );
    #$log->debug( "Session EID is " . 
    #    ( $session->get('eid') ? $session->get('eid') : "not present") );
    #$log->debug( "Session IP address is " . 
    #    ( $session->get('ip_addr') ? $session->get('ip_addr') : "not present" ) );
    #$log->debug( "Session last_seen is " . 
    #    ( $session->get('last_seen') ? $session->get('last_seen') : "not present" ) );

    # validate session:
    if ( $session->get('eid') and 
         $session->get('ip_addr') and 
         $session->get('last_seen') and
         $session->get('ip_addr') eq $remote_addr and
         _is_fresh( $session->get('last_seen') ) ) 
    {
        $log->debug( "Existing session!" );
        my $emp = App::Dochazka::REST::Model::Employee->load_by_eid( $session->get('eid') )->payload;
        die "missing employee object in session management" 
            unless $emp->isa( "App::Dochazka::REST::Model::Employee" ); 
        $self->_push_onto_context( { current => $emp->expurgate, } );
        $session->set('last_seen', time); 
        return 1;
    }

    $session->expire if $session->get('eid');  # invalid session: delete it
    return;
}


=head3 _is_fresh

Takes a single argument, which is assumed to be number of seconds since
epoch when the session was last seen. This is compared to "now" and if the
difference is greater than the DOCHAZKA_REST_SESSION_EXPIRATION_TIME site
parameter, the return value is false, otherwise true.

=cut

sub _is_fresh {
    my ( $last_seen ) = validate_pos( @_, { type => SCALAR } );
    return ( time - $last_seen > $site->DOCHAZKA_REST_SESSION_EXPIRATION_TIME )
        ? 0
        : 1;
}


=head3 _authenticate

Authenticate the nick associated with an incoming REST request.  Takes a nick
and a password (i.e., a set of credentials). Returns a status object, which
will have level 'OK' on success (with employee object in the payload), 'NOT_OK'
on failure.

=cut

sub _authenticate {
    my ( $nick, $password ) = @_;
    my ( $status, $emp );

    # empty credentials: fall back to demo/demo
    if ( $nick ) {
        $log->notice( "Login attempt from $nick" );
    } else {
        $log->notice( "Login attempt from (anonymous) -- defaulting to demo/demo" );
        $nick = 'demo'; 
        $password = 'demo'; 
    }

    $log->debug( "\$site->DOCHAZKA_LDAP is " . $site->DOCHAZKA_LDAP );

    # check if LDAP is enabled and if the employee exists in LDAP
    if ( ! $meta->META_DOCHAZKA_UNIT_TESTING and 
         $site->DOCHAZKA_LDAP and
         ldap_exists( $nick ) ) {

        $log->info( "Detected authentication attempt from $nick, a known LDAP user" );

        # - authenticate by LDAP bind
        if ( ldap_auth( $nick, $password ) ) {
            # successful LDAP auth
            # if the employee doesn't exist in the database, possibly autocreate
            if ( ! nick_exists( $nick ) ) {
                $log->info( "There is no employee $nick in the database: auto-creating" );
                if ( $site->DOCHAZKA_LDAP_AUTOCREATE ) {
                    my $emp = App::Dochazka::REST::Model::Employee->spawn(
                        nick => $nick,
                        remark => 'LDAP autocreate',
                    );
                    $status = $emp->insert;
                    if ( $status->not_ok ) {
                        $log->crit("Could not create $nick as new employee");
                        return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH' );
                    }
                    $log->notice( "Auto-created employee $nick, who was authenticated via LDAP" );
                } else {
                    $log->notice( "Authentication attempt from LDAP user $nick failed because the user is not in the database and DOCHAZKA_LDAP_AUTOCREATE is not enabled" );
                    return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH' );
                }
            }
        } else {
            return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH');
        }

        # load the employee object
        my $emp = App::Dochazka::REST::Model::Employee->load_by_nick( $nick )->payload;
        die "missing employee object in _authenticate" unless ref($emp) eq "App::Dochazka::REST::Model::Employee";
        return $CELL->status_ok( 'DOCHAZKA_EMPLOYEE_AUTH', payload => $emp );
    }

    # if not, authenticate against the password stored in the employee object.
    else {

        $log->notice( "Employee $nick not found in LDAP; reverting to internal auth" );

        # - check if this employee exists in database
        my $emp = nick_exists( $nick );

        if ( ! defined( $emp ) or ! $emp->isa( 'App::Dochazka::REST::Model::Employee' ) ) {
            $log->notice( "Rejecting login attempt from unknown user $nick" );
            return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH');
        }

        # - the password might be empty
        $password = '' unless defined( $password );
        my $passhash = $emp->passhash;
        $passhash = '' unless defined( $passhash );

        # - check password against passhash
        if ( $password eq $passhash ) {
            $log->notice( "Internal auth successful for employee $nick" );
            return $CELL->status_ok( 'DOCHAZKA_EMPLOYEE_AUTH', payload => $emp );
        } else {
            $log->info( "Internal auth failed for known employee $nick (mistyped password?)" );
            return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH' );
        }
    }
}            


=head2 forbidden

Authorization (ACL check) method.

First, parse the path and look at the method to determine which controller
action the user is asking us to perform. Each controller action has an ACL
associated with it, from which we can determine whether employees of each of
the four different privilege levels are authorized to perform that action.  

Requests for non-existent resources will always pass the ACL check.

If the request passes the ACL check, the mapping (if any) is pushed onto the
context for use in the L<"resource_exists"> routine which actually runs the
action.

=cut

sub forbidden {
    my ( $self ) = @_;

    # determine method
    my $method = uc $self->request->method;
    die "Bad method $method" unless $method =~ m/^(GET)|(POST)|(PUT)$/;

    # get router for this method (and initialize it if necessary)
    my $router = router( $method );
    $router = init_router( $method ) unless defined $router and $router->isa( 'Path::Router' );

    # decoded path was placed on context by 'service_available'
    my $path = $self->context->{'path'};
   
    # test path for a match
    if ( my $match = $router->match( $path ) ) {
        my $route = $match->route;

	# Path matches, so we now know exactly which resource the user is
	# asking for.  That means we also know the ACL profile of that
	# resource. And, since the user has already been authenticate, we know
	# who she is, too. 
        my $acl_profile = $route->defaults->{'acl_profile'};
        my $acl_priv = $self->context->{'current'}->{'priv'};

        # We are ready to run the ACL check
        my $acl_status = check_acl( $acl_profile, $acl_priv );
        return 1 unless $acl_status->ok;
        # ACL check passed

        my $uri = $site->DOCHAZKA_URI
            ? $site->DOCHAZKA_URI
            : $self->request->base->as_string;

        my $push_hash = { 
            'acl_priv' => $acl_priv,
            'target' => $route->target,
            'mapping' => $match->mapping, 
            'uri' => $uri,
            'method' => $method,
        };
        $log->debug( "Incoming request permitted: " . Dumper $push_hash );
        $self->_push_onto_context( $push_hash );

        return 0; # pass ACL check
    } else {
        # if the path doesn't match, we pass the request on to resource_exists
        return 0; 
    }
}


=head2 resource_exists

If the resource exists, its mapping will have been determined in the L<"forbidden">
routine. So, our job here is to execute the appropriate target if the mapping
exists. Executing the target builds the response entity.

=cut 

sub resource_exists {
    my ( $self ) = @_;

    $log->debug( "Entering resource_exists" );

    # if 'target' and 'mapping' exist, we can execute the target with the
    # mapping in the PARAMHASH
    if ( exists $self->context->{'target'} and exists $self->context->{'mapping'} ) {

        $log->debug( "Request for resource " . $self->context->{'path'} );

        my $target = $self->context->{'target'};

	# Get rid of the target CODEREF now that we're done with it, so it
	# doesn't trigger an error later, when we convert the context to JSON.
        #delete $self->context->{'target'};

        # This is where we actually execute the target, sending it the
        # entire context as an argument.
        my $status = &$target( $self->context );

	# The target returns a status object, but this time we simply push that
	# object onto the context (after "expurgating", or "unblessing", it).
        $self->_push_onto_context( { 'entity' => $status->expurgate } );

	# Returning 1 here signals that the requested resource exists. For
        # GET requests, this is the last test.
        return 1;
    }

    # We have already determined (in 'forbidden') whether or not the resource
    # exists. Non-existence of the resource is signalled by non-inclusion of
    # 'target' and 'mapping'. So if these two are not present, we return 0
    # and the client gets "404 Not Found".
    return 0; 
}


=head2 known_content_type

Looks at the 'Content-Type' header of POST and PUT requests, and generates
a "415 Unsupported Media Type" response if it is anything other than
'application/json'.

=cut

sub known_content_type {
    my ( $self, $content_type ) = @_;

    # for GET requests, we don't care about the content
    return 1 if $self->request->method eq 'GET';

    # some requests may not specify a Content-Type at all
    return 0 if not defined $content_type;

    # unfortunately, Web::Machine sometimes sends the content-type
    # as a plain string, and other times as an
    # HTTP::Headers::ActionPack::MediaType object
    if ( ref( $content_type ) eq '' ) {
        return ( $content_type eq 'application/json' ) ? 1 : 0;
    }
    if ( ref( $content_type ) eq 'HTTP::Headers::ActionPack::MediaType' ) {
        return $content_type->equals( 'application/json' ) ? 1 : 0;
    }
    return 0;
}


=head2 malformed_request

This test examines the request body. It can either be empty or contain
valid JSON; otherwise, a '400 Malformed Request' response is returned.
If it contains valid JSON, it is converted into a Perl hashref and 
stored in the 'request_body' attribute of the context.

=cut

sub malformed_request {
    my ( $self ) = @_;
    
    my $body = $self->request->content;
    if ( not defined $body or $body eq '' ) {
        $log->debug( "malformed_request: No request body" );
        return 0;
    }

    # there is a request body -- attempt to convert it
    my $result = 0;
    try {
        $self->_push_onto_context( { request_body => $JSON->decode( $body ) } );
    } 
    catch {
        $log->error( "Caught JSON error: $_" );
        $result = 1;
    };

    $log->debug( "Request body: " . Dumper $self->context->{'request_body'} ) unless $result;

    return $result;
}


=head2 process_post

Where POST requests are processed.

=cut

sub process_post {
    my $self = shift;
    $self->response->header('Content-Type' => 'application/json' );
    $self->response->body( $self->_make_json );
    return 1;
}



=head2 context

This method is where we store data that needs to be shared among
various "users" of the given object (i.e. among routines in this module).

=cut

sub context {
    my $self = shift;
    $self->{'context'} = shift if @_;
    $self->{'context'};
}


=head3 _push_onto_context

Takes a hashref and "pushes" it onto C<< $self->{'context'} >> for use later
on in the course of processing the request.

=cut

sub _push_onto_context {
    my $self = shift;
    my ( $hr ) = validate_pos( @_, { type => HASHREF } );

    my $context = $self->context;
    foreach my $key ( keys %$hr ) {
        $context->{$key} = $hr->{$key};
    }
    $self->context( $context );
}


=head2 _make_json

Makes the JSON for inclusion in the response entity.

=cut

sub _make_json {
    my ( $self ) = @_;
    my $before;
    my $after;
    if ( $ENV{'DOCHAZKA_DEBUG'} ) {
        # We can't send the context to JSON->encode directly because the
        # context contains a code reference and JSON->encode finds that
        # offensive: our deep_copy routine replaces the code reference with
        # a non-offensive placeholder string.
        $before = deep_copy( $self->context );
    } else {
        $before = unbless $self->context->{'entity'};
    }
    $after = JSON->new->pretty->encode( $before );
    $log->debug( "_make_json (before): " . Dumper $before );
    $log->debug( "_make_json (UTF-8): " . Dumper $after );
    return $after;
}


=head2 router

Takes one parameter -- an HTTP method (e.g. 'GET', 'POST'). Returns
the router instance for that method, which is stored in a package
variable.

=cut

sub router {
    my ( $method ) = validate_pos( @_, { regex => qr/(GET)|(POST)|(PUT)/ } );
    return $router_get if $method eq 'GET';
    return $router_post if $method eq 'POST';
    return $router_put if $method eq 'PUT';

    # We should never reach this point
    croak "AAAAAAAAAAAAHHHH!!!! Engulfed by the abyss";
}



=head2 init_router

Takes HTTP method and initializes the corresponding router.

=cut

sub init_router {
    my ( $method ) = validate_pos( @_, { regex => qr/(GET)|(POST)|(PUT)/ } );    	
    return _init_get() if $method eq 'GET';
    return _init_post() if $method eq 'POST';
    return _init_put() if $method eq 'PUT';
    # never reach this point
    die "AAAAAAAAAAAHHH! Engulfed by the abyss";
}


# initialization routine for GET router
sub _init_get {
    $router_get = Path::Router->new;
    die "Bad Path::Router object" unless $router_get->isa( 'Path::Router' );
    _populate_router( $router_get, $site->DISPATCH_RESOURCES_GET );
    $router_get;
}


# initialization routine for POST router
sub _init_post {
    $router_post = Path::Router->new;
    die "Bad router" unless $router_post->isa( 'Path::Router' );
    _populate_router( $router_post, $site->DISPATCH_RESOURCES_POST );
    $router_post;
}

# initialization routine for PUT router
sub _init_put {
    $router_put = Path::Router->new;
    die "Bad router" unless $router_put->isa( 'Path::Router' );
    _populate_router( $router_put, $site->DISPATCH_RESOURCES_PUT );
    $router_put;
}

sub _populate_router {
    my ( $router, $resources ) = @_;
    foreach my $key ( keys %$resources ) {
        no strict 'refs';
        $router->add_route( $key,
            defaults => {
                acl_profile => $resources->{$key}->{'acl_profile'},
            },
            target => \&{ $resources->{$key}->{'target'} },
        );
    }
    return;
}

1;
