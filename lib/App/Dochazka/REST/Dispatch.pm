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
# Path dispatcher module
# ------------------------

package App::Dochazka::REST::Dispatch;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use Scalar::Util qw( blessed );


=head1 NAME

App::Dochazka::REST::Dispatch - path dispatch





=head1 VERSION

Version 0.088

=cut

our $VERSION = '0.088';





=head1 DESCRIPTION

This module contains the state machine that converts incoming HTTP requests
into JSON responses.

=cut




sub _get_response {
    my ( $path ) = @_;

    # ========================================================================
    # big bad state machine
    # ========================================================================

    my $status; # allocate memory for response
    my $extra;



=head1 REQUEST SYNTAX

Documentation of L<App::Dochazka::REST> request syntax. Each section below
corresponds to a URL, in which you should replace C<dochazka.site> with the
FQDN of your own Dochazka REST server. The full URL is shown only for the
first couple entries. All responses are JSON-encoded status objects unless
otherwise noted.

=head2 C<< http://dochazka.site/ >>

(If this URL is opened in a browser, a HTML page will be displayed. The HTML
source code is defined in C<< $site->DOCHAZKA_REST_HTML >>.)

This is considered an empty request. The response will be the same as for 
L<"http://dochazka.site/version">.

=cut

    # 1. "" or "/"
    if ( $path eq '' or $path eq '/' ) {
        $status = _version( '' );
    }

=head2 C<< http://dochazka.site/version >>

Returns version number of the L<App::Dochazka::REST> that is
installed at the site. For example:

    /VERSION example here

=cut

    # 2. "/version"
    elsif ( $path =~ s/^\/version//i ) {
        $status = _version( '', $path );
    }

=head2 C<< http://dochazka.site/help >>

Returns a hopefully helpful status object containing a URL where this
documentation can be accessed.

=cut

    # 3. "/help"
    elsif ( $path =~ s/^\/help//i ) {
        $status = _help( '' );
    }

=head2 C<< /site/[PARAM] >>

(For the sake of brevity, the C<< http://dochazka.site >> part will be
omitted from here on.)

Returns value of the given site param in the payload.

=cut

    # 4. "/site"
    elsif ( $path =~ s/^\/site//i ) {
        $status = _site( $path );
    }

    # 999. anything else
    #else {
    #    $status = { unrecognized => $path };
    #}

    # if nothing matched, bail out
    return unless blessed $status;

    # sanitize the status object
    return $status->expurgate;
}


sub _version {
    my ( $rest ) = @_;
    my $status = $CELL->status_ok( 
        'DISPATCH_VERSION', 
        args => [ $VERSION ],
        payload => { 
            version => "$VERSION",
        },
    );
    $status->{'extraneous_url_part'} = $rest if $rest;
    return $status;
}


sub _help {
    my ( $rest ) = @_;
    my $du = "https://metacpan.org/pod/App::Dochazka::REST::Dispatch";
    my $status = $CELL->status_ok( 
        'DISPATCH_HELP', 
        args => [ $du ],
        payload => { 
            documentation_url => $du,
        },
    );
    $status->{'extraneous_url_part'} = $rest if $rest;
    return $status;
}


sub _site {
    no strict 'refs';
    my ( $path ) = @_;
    my ( $param, $value, $status );

    # correct value for $path looks like, e.g. '/DOCHAZKA_APPNAME'
    if ( $path =~ s/^\/([^\/]+)// ) {
        $param = $1;
        $value = $site->$param;
        $status = $value
            ? $CELL->status_ok( 
                  'DISPATCH_SITE_OK', 
                  args => [ $param ], 
                  payload => { $param => $value } 
              )
            : $CELL->status_err( 
                  'DISPATCH_SITE_NOT_DEFINED', 
                  args => [ $param ] 
              );
    } else {
        $status = $CELL->status_err( 'DISPATCH_SITE_MISSING' );
    }
    $status->{'extraneous_url_part'} = $path if $path;
    return $status;
}
    
1;
