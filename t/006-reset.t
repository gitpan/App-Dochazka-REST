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

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use DBI;
use App::Dochazka::REST qw( $REST );
use App::Dochazka::REST::Model::Employee;
use Test::More tests => 14;

# insert a testing employee
my $emp = App::Dochazka::REST::Model::Employee->spawn(
        dbh => 'TEST',
        acleid => 'TEST',
        aclpriv => 'admin',
        nick => 'missreset',
        fullname => 'Miss Reset Machine',
        email => 'parboiled@reset-pieces.com',
        passhash => 'foo',
        salt => 'bar',
        remark => 'why me?',
        hooligan => 'sneaking in',
   );
is( $emp->nick, 'missreset' );
is( $emp->fullname, 'Miss Reset Machine');
is( $emp->email, 'parboiled@reset-pieces.com');
is( $emp->passhash, 'foo');
is( $emp->salt, 'bar');
is( $emp->remark, 'why me?');
is( $emp->{hooligan}, undef, "No hooligans allowed" );

$emp->reset;

is( $emp->eid, undef );
is( $emp->fullname, undef );
is( $emp->nick, undef );
is( $emp->email, undef );
is( $emp->passhash, undef );
is( $emp->salt, undef );
is( $emp->remark, undef );


