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

#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More tests => 15;

BEGIN {
    use_ok( 'App::CELL' );
    use_ok( 'DBD::Pg' );
    use_ok( 'DBI' );
    use_ok( 'App::Dochazka::REST' );
    use_ok( 'App::Dochazka::REST::Spec' );
    use_ok( 'App::Dochazka::REST::Model::Activity' );
    use_ok( 'App::Dochazka::REST::Model::Employee' );
    use_ok( 'App::Dochazka::REST::Model::Interval' );
    use_ok( 'App::Dochazka::REST::Model::Lock' );
    use_ok( 'App::Dochazka::REST::Model::Privhistory' );
    use_ok( 'App::Dochazka::REST::Model::Schedule' );
    use_ok( 'App::Dochazka::REST::Model::Schedhistory' );
    use_ok( 'App::Dochazka::REST::Model::Schedintvls' );
    use_ok( 'App::Dochazka::REST::Model::Shared' );
    use_ok( 'App::Dochazka::REST::Util::Factory' );
}

#diag( "Testing App::Dochazka::REST $App::Dochazka::REST::VERSION, Perl $], $^X" );
