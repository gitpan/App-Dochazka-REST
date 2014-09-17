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
# Test helper functions module
# ------------------------

package App::Dochazka::REST::Test;

use strict;
use warnings;

use App::CELL qw( $CELL );
use HTTP::Request;
use JSON;
use Test::JSON;



=head1 NAME

App::Dochazka::REST::Test - Test helper functions





=head1 VERSION

Version 0.173

=cut

our $VERSION = '0.173';





=head1 DESCRIPTION

This module provides helper code for unit tests.

=cut




=head1 EXPORTS

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( req_root req_demo req_json_demo req_json_root req_html 
req_bad_creds status_from_json );




=head1 FUNCTIONS

=head2 req_root

Construct an HTTP request as 'root' (admin priv)

=cut

sub req_root {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic cm9vdDppbW11dGFibGU=' );
    $r->header( 'Accept' => 'application/json' );
    return $r;
}



=head2 req_demo

Construct an HTTP request as 'demo' (passerby priv)

=cut

sub req_demo {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpkZW1v' );
    $r->header( 'Accept' => 'application/json' );
    return $r;
}


=head2 req_json_demo

Construct an HTTP request for JSON as 'demo' (passerby priv)

=cut

sub req_json_demo {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpkZW1v' );
    $r->header( 'Accept' => 'application/json' );
    $r->header( 'Content-Type' => 'application/json' );  # necessary for POST to work
    return $r;
}


=head2 req_json_root

Construct an HTTP request for JSON as 'demo' (passerby priv)

=cut

sub req_json_root {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic cm9vdDppbW11dGFibGU=' );
    $r->header( 'Accept' => 'application/json' );
    $r->header( 'Content-Type' => 'application/json' );  # necessary for POST to work
    return $r;
}


=head2 req_html

Construct an HTTP request for HTML as 'demo' (passerby priv)

=cut

sub req_html {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpkZW1v' );
    $r->header( 'Accept' => 'text/html' );
    return $r;
}


=head2 req_bad_creds

Construct an HTTP request with improper credentials

=cut

sub req_bad_creds {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpibGJvc3Q=' );
    return $r;
}


=head2 status_from_json

Given a JSON string, check if it is valid JSON, blindly convert it into a
Perl hashref, bless it into 'App::CELL::Status', and send it back to caller.

=cut

sub status_from_json {
    my ( $json ) = @_;
    is_valid_json( $json );
    bless from_json( $json ), 'App::CELL::Status';
}

1;
