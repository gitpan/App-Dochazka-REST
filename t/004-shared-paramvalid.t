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
#
# some tests to ensure/demonstrate that routines in Shared.pm validate
# their parameters
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use DBI;
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Shared qw( load cud noof priv_by_eid schedule_by_eid );
use Test::Fatal;
use Test::More;

# call the load routine in all kinds of awful ways
like( exception { load(); }, qr/Mandatory parameters.+missing/ );
like( exception { load( 1, 2, 3 ); }, qr/Odd number of parameters in call/ );
like( exception { load( undef, 2, 3 ); }, qr/Odd number of parameters in call/ );
like( exception { load( class => 'App::Dochazka::REST::Model::Employee', ( 11..20 ) ); },
    qr/not listed in the validation options/);
like( exception { load( class => 'App::Dochazka::REST::Model::Employee', sql => [1], keys => [2] ); },
    qr/The 'sql' parameter.+not one of the allowed types: scalar/ );
like( exception { load( class => 'App::Dochazka::REST::Model::Employee', nick => 'nick', keys => [2] ); },
    qr/not listed in the validation options: nick/ );
like( exception { load( class => 'App::Dochazka::REST::Model::Employee', sql => 'bazblat', keys => 2 ); },
    qr/The 'keys' parameter.+not one of the allowed types: arrayref/ );

# do the bad stuff to the cud routine
like( exception { cud(); },  qr/Mandatory parameters.+missing/ );
like( exception { cud( object => {}, sql => 1, attrs => [] ); }, 
    qr/The 'object' parameter.+does not have the method: 'insert'/ );
my $object = App::Dochazka::REST::Model::Employee->spawn;
like( exception { cud( object => $object, sql => [], attrs => [] ); }, 
    qr/The 'sql' parameter.+not one of the allowed types: scalar/ );
like( exception { cud( object => $object, sql => 'scalar', attrs => 1 ); }, 
    qr/The 'attrs' parameter.+not one of the allowed types: arrayref/ );

# fire some potshots at noof
like( exception { noof(); }, qr/0 parameters.+but 1 was expected/ );
like( exception { noof( undef ); }, qr/Parameter #1.+not one of the allowed types: scalar/ );
like( exception { noof( [1..12] ); }, qr/Parameter #1.+not one of the allowed types: scalar/ );
like( exception { noof( (1..12) ); }, qr/12 parameters.+but 1 was expected/ );
is( noof( "Bad company" ), undef );

# bam bam at priv_by_eid
like( exception { priv_by_eid(); }, qr/0 parameters.+but 1 - 2 were expected/ );
like( exception { priv_by_eid( undef ); }, qr/Parameter #1.+not one of the allowed types: scalar/ );
#like( exception { priv_by_eid( 1, undef ); }, qr/Parameter #2.+not one of the allowed types: scalar/ );
like( exception { priv_by_eid( ( 1..12 ) ); }, qr/12 parameters.+but 1 - 2 were expected/ );

# bam bam at schedule_by_eid
like( exception { schedule_by_eid(); }, qr/0 parameters.+but 1 - 2 were expected/ );
like( exception { schedule_by_eid( undef ); }, qr/Parameter #1.+not one of the allowed types: scalar/ );
#like( exception { schedule_by_eid( 1, undef ); }, qr/Parameter #2.+not one of the allowed types: scalar/ );
like( exception { schedule_by_eid( ( 1..12 ) ); }, qr/12 parameters.+but 1 - 2 were expected/ );

done_testing;
