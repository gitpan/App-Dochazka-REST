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
# This package defines how our web server behaves. All the "heavy
# lifting" is done by Web::Machine and Plack.  
# ------------------------

package App::Dochazka::REST::Resource;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch;
use Data::Dumper;
use Encode qw( decode_utf8 );
use JSON;
use Web::Machine::Util qw( create_header );

# methods/attributes not defined in this module will be inherited from:
use parent 'Web::Machine::Resource';


=head1 NAME

App::Dochazka::REST::Resource - web resource definition




=head1 VERSION

Version 0.099

=cut

our $VERSION = '0.099';





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

# a package variable to streamline calls to the JSON module
my $JSON = JSON->new->allow_nonref->pretty;




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
    my $server_status = App::Dochazka::REST::dbh->status;
    $log->info( 'render_html \$self->context' );
    $log->info( Dumper( $self->context ) );
    
    my $msgobj = $CELL->msg( 
        'DOCHAZKA_REST_HTML', 
        $VERSION, 
        $self->context->{'path'},
        $JSON->encode( $self->context->{'response'} ), 
        $server_status 
    );
    $msgobj
        ? $msgobj->text
        : '<html><body><h1>Internal Error</h1><p>See Resource.pm->render_html</p></body></html>';
}



=head2 render_json

Encode the context as a JSON string.

=cut

sub render_json { $JSON->encode( (shift)->context->{'response'} );  }



=head2 context

This method is where we store data that needs to be shared among
various "users" of the given object (i.e. among routines in this module).

=cut

sub context {
    my $self = shift;
    $self->{'context'} = shift if @_;
    $self->{'context'};
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

Authenticate the originator of the request, using HTTP Basic
Authentication.

=cut

sub is_authorized {
    my ( $self, $auth_header ) = @_;

    if ( $auth_header ) {
        return 1 if $auth_header->username eq 'demo'
                 && $auth_header->password eq 'demo';
    }
    return create_header(
        'WWWAuthenticate' => [ 'Basic' => ( realm => 'User: demo, Password: demo' ) ]
    ); 

}


=head2 forbidden

Parse the path to determine what is being asked of us. At the same time,
check if the user (employee) is authorized to do that.

=cut

sub forbidden {
    my ( $self ) = @_;

    # The "path" is a series of bytes which are assumed to be encoded in UTF-8.
    # In order to process them, they must first be "decoded" into Perl characters.
    my $path = decode_utf8( $self->request->path_info );

    # Put the path into the context
    $self->context( { path => $path } );
   
    # Determine authorization status (hardcoded for now)
    my $status = App::Dochazka::REST::Dispatch::is_auth( eid => 1, priv => 'admin', path => $path );

    if ( $status->ok ) { # not forbidden to do that
        my $rs = &{ $status->payload->{'rout'} }( @{ $status->payload->{'args'} } );
        $self->_push( { 'response' => $rs->expurgate } );
        return 0;
    }

    # forbidden to do that
    return 1;
}


=head2 _push

Takes a hashref and "pushes" it onto C<< $self->{'context'} >>

=cut

sub _push {
    my ( $self, $hr ) = @_;

    my $context = $self->context;
    foreach my $key ( keys %$hr ) {
        $context->{$key} = $hr->{$key};
    }
    $self->context( $context );
}

1;
