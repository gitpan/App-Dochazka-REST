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
# employee_Config.pm
#
# configuration parameters related to employees
# -----------------------------------

# 
set( 'SQL_EMPLOYEE_SELECT_BY_EID', q/
      SELECT eid, fullname, nick, email, passhash, salt, remark,
          current_priv(eid) AS priv, current_schedule(eid) AS schedule 
      FROM employees WHERE eid=?/ );

#
set( 'SQL_EMPLOYEE_SELECT_BY_NICK', q/
      SELECT eid, fullname, nick, email, passhash, salt, remark,
          current_priv(eid) AS priv, current_schedule(eid) AS schedule 
      FROM employees WHERE nick=?/ );

#
set( 'SQL_EMPLOYEE_PRIV_AT_TIMESTAMP', q/
      SELECT priv_at_timestamp($1, CAST( $2 AS TIMESTAMP WITHOUT TIME ZONE ) )
      / );

#
set( 'SQL_EMPLOYEE_SCHEDULE_AT_TIMESTAMP', q/
      SELECT schedule_at_timestamp($1, CAST( $2 AS TIMESTAMP WITHOUT TIME ZONE ) )
      / );

#
set( 'SQL_EMPLOYEE_CURRENT_PRIV', q/
      SELECT current_priv(?)/ );

#
set( 'SQL_EMPLOYEE_CURRENT_SCHEDULE', q/
      SELECT current_schedule(?)/ );

#
set( 'SQL_EMPLOYEE_INSERT', q/
      INSERT INTO employees 
                (fullname, nick, email, passhash, salt, remark)
      VALUES    (?,        ?,    ?,     ?,        ?,    ?) 
      RETURNING  eid, fullname, nick, email, passhash, salt, remark
      / );

#
set( 'SQL_EMPLOYEE_UPDATE', q/
      UPDATE employees SET fullname = ?, nick = ?, email = ?,
         passhash = ?, salt = ?, remark = ?  
      WHERE eid = ?
      RETURNING  eid, fullname, nick, email, passhash, salt, remark
      / );

#
set( 'SQL_EMPLOYEE_DELETE', q/
      DELETE FROM employees WHERE eid = ? RETURNING eid
      / );


# -----------------------------------
# DO NOT EDIT ANYTHING BELOW THIS LINE
# -----------------------------------
use strict;
use warnings;

1;
