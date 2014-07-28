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

use App::CELL qw( $CELL $log $site );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch;
use App::Dochazka::REST::Model::Employee;
use Data::Structure::Util qw( unbless );
use Encode qw( decode_utf8 );
use JSON;
use Web::Machine::Util qw( create_header );

# methods/attributes not defined in this module will be inherited from:
use parent 'Web::Machine::Resource';


=head1 NAME

App::Dochazka::REST::Resource - web resource definition




=head1 VERSION

Version 0.109

=cut

our $VERSION = '0.109';





=head1 SYNOPSIS

In PSGI file:

    use Web::Machine;

    Web::Machine->new(
        resource => 'App::Dochazka::REST::Resource',
    )->to_app;




=head1 DESCRIPTION

This is where we override the default versions of various methods
defined by our "highway to H.A.T.E.O.S.": L<Web::Machine>.

(Methods not defined in this module will be inherited from
L<Web::Machine::Resource>.)

Do note, however, that none of the routines in this module are called by
L<App::Dochazka::REST>. 

=cut




=head1 PACKAGE VARIABLES

=cut

# a package variable to streamline calls to the JSON module
my $JSON = JSON->new->allow_nonref->pretty;
# a package variable to store Path::Router instance for GET requests
my $router_get;
# a package variable to store Path::Router instance for POST requests
my $router_post;


=head1 METHODS


=head2 content_types_provided

L<Web::Machine> calls this routine to determine how to generate the response
body. It says: "generate responses in JSON using the 'render' method".

=cut
 
sub content_types_provided { [
    { 'text/html' => 'render_html' },
    { 'application/json' => 'render_json' },
] }



=head2 render_html

Whip out some HTML to educate passersby.

=cut

sub render_html { 
    my ( $self ) = @_;
    
    my $msgobj = $CELL->msg( 
        'DOCHAZKA_REST_HTML', 
        $VERSION, 
        $self->_make_json,
        App::Dochazka::REST::dbh->status,
    );
    $msgobj
        ? $msgobj->text
        : '<html><body><h1>Internal Error</h1><p>See Resource.pm->render_html</p></body></html>';
}



=head2 render_json

Encode the context as a JSON string.

=cut

sub render_json { 
    my ( $self ) = @_;
    $self->_make_json;
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


=head2 router

Accessor. Takes one parameter -- the method. Returns the router instance for that method.

=cut

sub router {
    my ( $self, $method ) = @_;
    die "No method" unless defined $method;
    $method = lc $method;
    return $self->_router_get if $method eq 'get';
    return $self->_router_post if $method eq 'post';
    die "Bad method $method";
}


sub _router_get {
    my $self = shift;
    $router_get = shift if @_;
    $router_get;
}


sub _router_post {
    my $self = shift;
    $router_post = shift if @_;
    $router_post;
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

sub allowed_methods { return [ 'GET' ]; }



=head2 uri_too_long

Is the URI too long?

=cut

sub uri_too_long {
    my ( $self, $uri ) = @_;

    return length $uri > $site->DOCHAZKA_URI_MAX_LENGTH
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

    if ( $auth_header ) {
        my $username = $auth_header->username;
        my $password = $auth_header->password;
        my $auth_status = _authenticate( $username, $password );
        if ( $auth_status->ok ) {
            my $emp = $auth_status->payload;
            $self->_push_onto_context( { current => $emp->expurgate, } );
            return 1;
        }
    }
    return create_header(
        'WWWAuthenticate' => [ 'Basic' => ( realm => $CELL->msg( 'DOCHAZKA_BASIC_AUTH_MESSAGE' )->text ) ]
    ); 

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
    my $method = lc $self->request->method;
    die "Bad method $method" unless $method eq 'get';
    my $router = $self->router( $method );
    App::Dochazka::REST::Dispatch->init( $method ) unless $router;
    $router = $self->router( $method );
    die "Problem with router" unless $router->isa( 'Path::Router' );

    # The "path" is a series of bytes which are assumed to be encoded in UTF-8.
    # In order to process them, they must first be "decoded" into Perl characters.
    my $path = decode_utf8( $self->request->path_info );
    $self->_push_onto_context( { 'path' => $path } );
   
    # test path for a match
    if ( my $match = $router->match( $path ) ) {
        my $route = $match->route;
        $self->_push_onto_context( { 
            'target' => $route->target,
            'mapping' => $match->mapping, 
            'uri' => $self->request->base->as_string,
        } );
        # target is executed twice: this is the first time, when we
        # send it 'acleid' and 'aclpriv', which indicates to the target
        # that we want to get the ACL status, which is indicated by the
        # status level (OK/NOT_OK)
        my $acl_status = $route->target->( 
            acleid => $self->context->{'current'}->{'eid'},
            aclpriv => $self->context->{'current'}->{'priv'},
        );
        return 1 unless $acl_status->ok; # fail ACL check
    }
    return 0; # pass ACL check

}


=head2 resource_exists

If the resource exists, its mapping will have been determined in the L<"forbidden">
routine. So, our job here is to execute the appropriate target if the mapping
exists. Executing the target builds the response entity.

=cut 

sub resource_exists {
    my ( $self ) = @_;

    # if 'target' and 'mapping' exist, we can execute the target with the
    # mapping in the PARAMHASH
    if ( exists $self->context->{'target'} and exists $self->context->{'mapping'} ) {

        my $target = $self->context->{'target'};

	# Get rid of the target CODEREF now that we're done with it, so it
	# doesn't trigger an error later, when we convert the context to JSON.
        delete $self->context->{'target'};

        # This is the second time we execute the target (first was in 'forbidden'
        # to get the ACL status. This time, instead of ACL data we send the 
	# entire request context. We send the entire context because, at this
	# point, we don't know exactly which items from the context the
	# target will need.
        my $status = &$target( 'context' => $self->context, );

        # 'expurgate' the status to get rid of unnecessary ballast
        my $entity = $status->expurgate;

	# The target returns a status object, but this time we simply push that
	# object onto the context (after "expurgating", or "unblessing", it).
        $self->_push_onto_context( { 'entity' => $entity } );

	# Returning 1 here signals that the request was processed successfully
	# (200 OK) and everything needed to construct the response is in the
	# context.
        return 1;
    }

    # We have already determined (in 'forbidden') whether or not the resource
    # exists. Non-existence of the resource is signalled by non-inclusion of
    # 'target' and 'mapping'. So if these two are not present, we return 0
    # and the client gets "404 Not Found".
    return 0; 
}



=head2 _push_onto_context

Takes a hashref and "pushes" it onto C<< $self->{'context'} >> for use later
on in the course of processing the request.

=cut

sub _push_onto_context {
    my ( $self, $hr ) = @_;

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
    my $what = $ENV{'DOCHAZKA_DEBUG'}
        ? $self->context
        : $self->context->{'entity'};
    $JSON->encode( unbless $what );
}


=head2 _authenticate

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
        $log->notice( "Login attempt from (anonymous)" );
        $nick = 'demo'; 
        $password = 'demo'; 
    }

    # check if the employee exists in LDAP
    if ( App::Dochazka::REST::LDAP::ldap_exists( $nick ) ) {

        # employee exists in LDAP
        # - check if exists in database; create if necessary
        $status = App::Dochazka::REST::Model::Employee->load_by_nick( $nick );
        if ( $status->not_ok ) {
            $emp = App::Dochazka::REST::Model::Employee->spawn( nick => $nick );
            $status = $emp->insert;
            return $status unless $status->ok;
        }
        # - authenticate by LDAP bind
        if ( App::Dochazka::REST::LDAP::ldap_auth( $nick, $password ) ) {
            return $CELL->status_ok( 'DOCHAZKA_EMPLOYEE_AUTH', payload => $emp );
        } else {
            return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH' );
        }
    }

    # if not, authenticate against the password stored in the employee object.
    else {
        # - check if this employee exists in database
        $status = App::Dochazka::REST::Model::Employee->load_by_nick( $nick );
        if ( $status->not_ok ) {
            return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH' );
        }
        # - employee exists: get it
        $emp = $status->payload;
        # - the password might be empty
        $password = '' unless defined( $password );
        my $passhash = $emp->passhash;
        $passhash = '' unless defined( $passhash );
        # - check password against passhash
        if ( $password eq $passhash ) {
            return $CELL->status_ok( 'DOCHAZKA_EMPLOYEE_AUTH', payload => $emp );
        } else {
            return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH' );
        }
    }
}            


1;
