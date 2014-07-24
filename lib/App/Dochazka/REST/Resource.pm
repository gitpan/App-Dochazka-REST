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

Version 0.096

=cut

our $VERSION = '0.096';





=head1 SYNOPSIS

In PSGI file:

    use Web::Machine;

    Web::Machine->new(
        resource => 'App::Dochazka::REST::Resource',
    )->to_app;




=head1 DESCRIPTION

This is where we provide our own versions of various methods
used by our "web framework": L<Web::Machine>.

Methods/attributes not defined in this module will be inherited from
L<Web::Machine::Resource>.

=cut

# a package variable to streamline calls to the JSON module
my $JSON = JSON->new->pretty;




=head1 METHODS


=head2 content_types_provided

L<Web::Machine> calls this routine to determine how to generate the response
body. It says: "generate responses in JSON using the 'render' method".

=cut
 
sub content_types_provided { [
    { 'application/json' => 'render_json' },
    { 'text/html' => 'render_html' },
] }



=head2 render_json

Encode the context as a JSON string.

=cut

sub render_json { $JSON->encode( (shift)->context );  }



=head2 render_html

Whip out some HTML to educate passersby.

=cut

sub render_html { 
    $log->info( "Entering render_html" );
    my $server_status = App::Dochazka::REST::dbh->status;
    $log->info( "Server status is $server_status");
    my $msgobj = $CELL->msg( 'DOCHAZKA_REST_HTML', $VERSION, $server_status );
    $msgobj
        ? $msgobj->text
        : '<html><body><h1>Internal Error</h1><p>See Resource.pm->render_html</p></body></html>';
}



=head2 context

This method is used to store the request "context", i.e. the part of the URL
after the hostname.

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

Authenticate the originator of the request (using HTTP Basic
Authentication) and determine whether the request is authorized.

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



=head2 resource_exists

Path dispatcher method. (The "path" is the part of the URL following the
hostname.)  This is the meat of the REST server, where we determine what the
responses will be to various requests. 

=cut

sub resource_exists {
    my ( $self ) = @_;

    # The "path" is a series of bytes which are assumed to be encoded in UTF-8.
    # In order to process them, they must first be "decoded" into Perl characters.
    my $path = decode_utf8( $self->request->path_info );

    # Since the path dispatching state machine is complex, it resides in 
    # a separate module. The C<_get_response> routine in that module
    # returns the data structure that will be encoded as JSON and sent to
    # the client.
    $self->context( App::Dochazka::REST::Dispatch::_get_response( $path ) );

}

1;
