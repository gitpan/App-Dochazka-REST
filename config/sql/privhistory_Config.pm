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

# -----------------------------------
# Dochazka-REST
# -----------------------------------
# priv_Config.pm
#
# SQL code related to privilege levels
# -----------------------------------

# SQL_PRIVHISTORY_INSERT
#     SQL to insert a single row in privhistory table
#
set( 'SQL_PRIVHISTORY_INSERT', q/
      INSERT INTO privhistory (eid, priv, effective, remark) 
      VALUES (?, ?, ?, ?)
      RETURNING phid, eid, priv, effective, remark
      / );

# SQL_PRIVHISTORY_DELETE
#     SQL to delete a single row from privhistory table
#
set( 'SQL_PRIVHISTORY_DELETE', q/
      DELETE FROM privhistory WHERE phid = ?
      RETURNING phid, eid, priv, effective, remark
      / );

# SQL_PRIVHISTORY_SELECT_ARBITRARY
#     SQL to select from privhistory based on EID and arbitrary timestamp
#
set( 'SQL_PRIVHISTORY_SELECT_ARBITRARY', q/
      SELECT phid, eid, priv, effective, remark FROM privhistory
      WHERE eid = ? and effective <= ?
      ORDER BY effective DESC
      FETCH FIRST ROW ONLY
      / );

# SQL_PRIVHISTORY_SELECT_CURRENT
#     SQL to select from privhistory based on EID and current timestamp
#
set( 'SQL_PRIVHISTORY_SELECT_CURRENT', q/
      SELECT phid, eid, priv, effective, remark FROM privhistory
      WHERE eid = ? and effective <= CAST( current_timestamp AS TIMESTAMP WITHOUT TIME ZONE )
      ORDER BY effective DESC
      FETCH FIRST ROW ONLY
      / );

# SQL_PRIVHISTORY_SELECT_BY_PHID
#     SQL to select a privhistory record by its phid
set( 'SQL_PRIVHISTORY_SELECT_BY_PHID', q/
      SELECT phid, eid, priv, effective, remark FROM privhistory
      WHERE phid = ? 
      / );

# SQL_PRIVHISTORY_SELECT_RANGE
#     SQL to select a range of privhistory records
set( 'SQL_PRIVHISTORY_SELECT_RANGE', q/
      SELECT phid, eid, priv, effective, remark FROM privhistory 
      WHERE eid = ? AND effective <@ CAST( ? AS tsrange )
      ORDER BY effective
      / );

# -----------------------------------
# DO NOT EDIT ANYTHING BELOW THIS LINE
# -----------------------------------
use strict;
use warnings;

1;