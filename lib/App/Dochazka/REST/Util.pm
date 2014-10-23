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

package App::Dochazka::REST::Util;

use 5.012;
use strict;
use warnings FATAL => 'all';



=head1 NAME

App::Dochazka::REST::Util - miscellaneous utilities




=head1 VERSION

Version 0.207

=cut

our $VERSION = '0.207';




=head1 SYNOPSIS

Miscellaneous utilities

    use App::Dochazka::REST::Util::Timestamp;

    ...




=head1 EXPORTS

This module provides the following exports:

=over 

=item L<deep_copy> (function)

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( deep_copy );




=head1 FUNCTIONS

=head2 deep_copy

Make a deep copy of a data structure, replacing code references with
a scalar 'CODEREF' so they can be JSON->encoded. Taken from 

    http://www.perlmonks.org/?node_id=620173

=cut

sub deep_copy {
    my $this = shift;
    return unless defined $this;
    if ( not ref $this ) {
        $this
    }
    elsif ( ref $this eq "HASH" ) {
        +{ map { $_ => _deep_copy( $this->{ $_ } ) } keys %$this }
    }
    elsif ( ref $this eq "ARRAY" ) {
        [map _deep_copy( $_ ), @$this]
    }
    elsif ( ref $this eq "CODE" ) {
        'CODEREF'
    }
    else {
        die "What's a " . ref $this . "?" 
    }
}

1;
