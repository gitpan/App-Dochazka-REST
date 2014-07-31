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
# Database handle module
# ------------------------

package App::Dochazka::REST::dbh;

use strict;
use warnings;




=head1 NAME

App::Dochazka::REST::dbh - database handle module (parent of data model classes)





=head1 VERSION

Version 0.122

=cut

our $VERSION = '0.122';





=head1 DESCRIPTION

This module is the parent of all the data model classes. Its sole purpose is to
transparently provide the data model classes with a database handle.

=cut



our $dbh;


=head1 METHODS

=head2 init

Something like a constructor.

=cut

sub init {
    my ( $class, $recvd_dbh ) = @_;
    $dbh = $recvd_dbh;
    return;
}


=head2 dbh

Something like an instance method, to be accessed via inheritance.

=cut

sub dbh { $dbh; }


=head2 status

Report whether the database server is up or down.

=cut

sub status {
    return $dbh->ping ? "UP" : "DOWN" if defined $dbh;
    return "DOWN";
}
   
1;
