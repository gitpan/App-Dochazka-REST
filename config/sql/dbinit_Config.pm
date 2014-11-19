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
# dbinit_Config.pm
#
# SQL vitals
# -----------------------------------

# For connecting to the database
set( 'DBINIT_CONNECT_USER', 'postgres' );
# This next one should be overrided in Dochazka_SiteConfig.pm with the real
# postgres password
set( 'DBINIT_CONNECT_AUTH', 'bogus_password_to_be_overrided' );

# DBINIT_CREATE
# 
#  A list of SQL statements that are executed when the database is first
#  created, to set up the table structure, etc. -- see the create_tables
#  subroutine in REST.pm 
#
set( 'DBINIT_CREATE', [

    q/SET client_min_messages=WARNING/,

    q#-- rounds a timestamp value to the nearest 5 minutes
      CREATE OR REPLACE FUNCTION round_time (TIMESTAMP)
      RETURNS TIMESTAMP AS $$
          SELECT date_trunc('hour', $1) + INTERVAL '5 min' * ROUND(date_part('minute', $1) / 5.0)
      $$ LANGUAGE sql IMMUTABLE#,

    q/-- employee identification data
      -- the only required field is eid (Employee ID)
      -- fullname, nick, and email must be UNIQUE, but may be NULL
      CREATE TABLE IF NOT EXISTS employees (
        eid       serial PRIMARY KEY,
        fullname  varchar(96) UNIQUE,
        nick      varchar(32) UNIQUE NOT NULL,
        email     text UNIQUE,
        passhash  text,
        salt      text,
        remark    text,
        stamp     json,
        CONSTRAINT kosher_nick CHECK (nick ~* '^[A-Za-z0-9][A-Za-z0-9]+$')
      )/,

    q/-- trigger function to make 'eid' field immutable
    CREATE OR REPLACE FUNCTION eid_immutable() RETURNS trigger AS $IMM$
      BEGIN
          IF OLD.eid <> NEW.eid THEN
              RAISE EXCEPTION 'employees.eid field is immutable'; 
          END IF;
          RETURN NEW;
      END;
    $IMM$ LANGUAGE plpgsql/,
    
    q/-- trigger the trigger
    CREATE TRIGGER no_eid_update BEFORE UPDATE ON employees
      FOR EACH ROW EXECUTE PROCEDURE eid_immutable()/,
    
    q/-- sequence for use with the schedintvls table -- this is a 
      -- "scratch" version of the SID, if you will
      CREATE SEQUENCE scratch_sid_seq
    /,

    q/-- "scratch" table, used to test schedules for overlapping intervals
      -- before converting them with translate_schedintvl for insertion
      -- them in the 'schedules' table: records inserted into schedintvls
      -- should be deleted after use
      CREATE TABLE IF NOT EXISTS schedintvls (
        int_id  serial PRIMARY KEY,
        ssid    integer NOT NULL,
        intvl   tsrange NOT NULL,
        EXCLUDE USING gist (ssid WITH =, intvl WITH &&)
      )/,

    q/CREATE OR REPLACE FUNCTION valid_schedintvl() RETURNS trigger AS $$
        BEGIN
            IF MAX(upper(NEW.intvl)) - MIN(lower(NEW.intvl)) > '168:0:0' THEN
                RAISE EXCEPTION 'schedule intervals must fall within a 7-day range';
            END IF;
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql IMMUTABLE/,

    q/CREATE OR REPLACE FUNCTION valid_intvl() RETURNS trigger AS $$
        BEGIN
            IF ( isempty(NEW.intvl) ) OR
               ( NOT lower_inc(NEW.intvl) ) OR
               ( upper_inc(NEW.intvl) ) OR
               ( lower_inf(NEW.intvl) ) OR
               ( upper_inf(NEW.intvl) ) THEN
                RAISE EXCEPTION 'illegal interval';
            END IF;
            IF ( upper(NEW.intvl) != round_time(upper(NEW.intvl)) ) OR
               ( lower(NEW.intvl) != round_time(lower(NEW.intvl)) ) THEN
                RAISE EXCEPTION 'upper and lower bounds of interval must be evenly divisible by 5 minutes';
            END IF;
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql IMMUTABLE/,

    q/CREATE TRIGGER valid_schedintvl BEFORE INSERT OR UPDATE ON schedintvls
        FOR EACH ROW EXECUTE PROCEDURE valid_schedintvl()/,

    q/CREATE TRIGGER valid_intvl BEFORE INSERT OR UPDATE ON schedintvls
        FOR EACH ROW EXECUTE PROCEDURE valid_intvl()/,

    q#-- Given a SID in schedintvls, returns all the intervals for that
      -- SID. Each interval is expressed as a list ('row', 'composite
      -- value') consisting of 4 strings (two pairs). The first pair of
      -- strings (e.g., "WED" "08:00") denotes the lower bound of the
      -- range, while the second pair denotes the upper bound
      CREATE OR REPLACE FUNCTION translate_schedintvl ( 
          ssid int,
          OUT low_dow text,
          OUT low_time text,
          OUT high_dow text,
          OUT high_time text
      ) AS $$
          SELECT 
              to_char(lower(intvl)::timestamp, 'DY'),
              to_char(lower(intvl)::timestamp, 'HH24:MI'),
              to_char(upper(intvl)::timestamp, 'DY'),
              to_char(upper(intvl)::timestamp, 'HH24:MI')
          FROM schedintvls
          WHERE int_id = $1
      $$ LANGUAGE sql IMMUTABLE#,

    q/-- !!!change 'text' to 'jsonb' when PostgreSQL 9.4 becomes
      -- !!!available
      CREATE TABLE IF NOT EXISTS schedules (
        sid        serial PRIMARY KEY,
        schedule   text UNIQUE NOT NULL,
        disabled   boolean,
        remark     text
      )/,

    q/-- trigger function to detect attempts to change 'schedule' field
    CREATE OR REPLACE FUNCTION schedule_immutable() RETURNS trigger AS $IMM$
      BEGIN
          IF OLD.schedule <> NEW.schedule THEN
              RAISE EXCEPTION 'schedule field is immutable'; 
          END IF;
          IF OLD.sid <> NEW.sid THEN
              RAISE EXCEPTION 'schedules.sid field is immutable'; 
          END IF; 
          RETURN NEW;
      END;
    $IMM$ LANGUAGE plpgsql/,
    
    q/-- trigger the trigger
    CREATE TRIGGER no_schedule_update BEFORE UPDATE ON schedules
      FOR EACH ROW EXECUTE PROCEDURE schedule_immutable()/,
    
    q/CREATE TABLE IF NOT EXISTS schedhistory (
        shid       serial PRIMARY KEY,
        eid        integer REFERENCES employees (eid) NOT NULL,
        sid        integer REFERENCES schedules (sid) NOT NULL,
        effective  timestamp NOT NULL,
        remark     text,
        stamp      json,
        UNIQUE (eid, effective)
      )/,

    q/-- trigger function to make 'shid' field immutable
    CREATE OR REPLACE FUNCTION shid_immutable() RETURNS trigger AS $IMM$
      BEGIN
          IF OLD.shid <> NEW.shid THEN
              RAISE EXCEPTION 'schedhistory.shid field is immutable'; 
          END IF;
          RETURN NEW;
      END;
    $IMM$ LANGUAGE plpgsql/,
    
    q/-- trigger the trigger
    CREATE TRIGGER no_shid_update BEFORE UPDATE ON schedhistory
      FOR EACH ROW EXECUTE PROCEDURE shid_immutable()/,
    
    q/CREATE TYPE privilege AS ENUM ('passerby', 'inactive', 'active', 'admin')/,

    q/CREATE TABLE IF NOT EXISTS privhistory (
        phid       serial PRIMARY KEY,
        eid        integer REFERENCES employees (eid) NOT NULL,
        priv       privilege NOT NULL,
        effective  timestamp NOT NULL,
        remark     text,
        stamp      json,
        UNIQUE (eid, effective)
    )/,

    q/-- trigger function to make 'phid' field immutable
    CREATE OR REPLACE FUNCTION phid_immutable() RETURNS trigger AS $IMM$
      BEGIN
          IF OLD.phid <> NEW.phid THEN
              RAISE EXCEPTION 'privhistory.phid field is immutable'; 
          END IF;
          RETURN NEW;
      END;
    $IMM$ LANGUAGE plpgsql/,
    
    q/-- trigger the trigger
    CREATE TRIGGER no_phid_update BEFORE UPDATE ON privhistory
      FOR EACH ROW EXECUTE PROCEDURE phid_immutable()/,
    
    q/CREATE OR REPLACE FUNCTION round_effective() RETURNS trigger AS $$
        BEGIN
            NEW.effective = round_time(NEW.effective);
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql IMMUTABLE/,

    q/CREATE TRIGGER round_effective BEFORE INSERT OR UPDATE ON schedhistory
        FOR EACH ROW EXECUTE PROCEDURE round_effective()/,

    q/CREATE TRIGGER round_effective BEFORE INSERT OR UPDATE ON privhistory
        FOR EACH ROW EXECUTE PROCEDURE round_effective()/,

    q#-- generalized function to get privilege level for an employee
      -- as of a given timestamp
      -- the complicated SELECT is necessary to ensure that the function
      -- always returns a valid privilege level -- if the EID given doesn't
      -- have a privilege level for the timestamp given, the function
      -- returns 'passerby' (for more information, see t/003-current-priv.t)
      CREATE OR REPLACE FUNCTION priv_at_timestamp (INTEGER, TIMESTAMP WITHOUT TIME ZONE)
      RETURNS privilege AS $$
          SELECT priv FROM (
              SELECT 'passerby' AS priv, '4713-01-01 BC' AS effective 
              UNION
              SELECT priv, effective FROM privhistory 
                  WHERE eid=$1 AND effective <= $2
          ) AS something_like_a_virtual_table
          ORDER BY effective DESC
          FETCH FIRST ROW ONLY
      $$ LANGUAGE sql IMMUTABLE#,

    q#-- this function will return 'jsonb' after PostgreSQL 9.4 comes out!!!
      CREATE OR REPLACE FUNCTION schedule_at_timestamp (INTEGER, TIMESTAMP WITHOUT TIME ZONE)
      RETURNS text AS $$
          SELECT schedule FROM (
              SELECT '{}' AS schedule, '4713-01-01 BC' AS effective
              UNION
              SELECT schedules.schedule, schedhistory.effective
                  FROM schedules, schedhistory
                  WHERE schedules.sid = schedhistory.sid AND
                        schedhistory.eid=$1 AND 
                        schedhistory.effective <= $2
          ) AS something_like_a_virtual_table
          ORDER BY effective DESC
          FETCH FIRST ROW ONLY
      $$ LANGUAGE sql IMMUTABLE#,

    q#-- wrapper function to get priv as of current timestamp
      CREATE OR REPLACE FUNCTION current_priv (INTEGER)
      RETURNS privilege AS $$
          SELECT priv_at_timestamp($1, CAST( current_timestamp AS TIMESTAMP WITHOUT TIME ZONE ) )
      $$ LANGUAGE sql IMMUTABLE#,

    q#-- wrapper function to get schedule as of current timestamp
      -- this function will return 'jsonb' after PostgreSQL 9.4 comes out!!!
      CREATE OR REPLACE FUNCTION current_schedule (INTEGER)
      RETURNS text AS $$
          SELECT schedule_at_timestamp($1, CAST( current_timestamp AS TIMESTAMP WITHOUT TIME ZONE ) )
      $$ LANGUAGE sql IMMUTABLE#,

    q/-- activities
      CREATE TABLE activities (
          aid        serial PRIMARY KEY,
          code       varchar(32) UNIQUE NOT NULL,
          long_desc  text,
          remark     text,
          disabled   boolean,
          CONSTRAINT kosher_code CHECK (code ~* '^[A-Za-z][A-Za-z0-9_]+$')
      )/,
  
    q/-- trigger function to make 'aid' field immutable
    CREATE OR REPLACE FUNCTION aid_immutable() RETURNS trigger AS $IMM$
      BEGIN
          IF OLD.aid <> NEW.aid THEN
              RAISE EXCEPTION 'activities.aid field is immutable'; 
          END IF;
          RETURN NEW;
      END;
    $IMM$ LANGUAGE plpgsql/,
    
    q/-- trigger the trigger
    CREATE TRIGGER no_aid_update BEFORE UPDATE ON activities
      FOR EACH ROW EXECUTE PROCEDURE aid_immutable()/,
    
    q/CREATE OR REPLACE FUNCTION code_to_upper() RETURNS trigger AS $$
        BEGIN
            NEW.code = upper(NEW.code);
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql IMMUTABLE/,

    q/CREATE TRIGGER code_to_upper BEFORE INSERT OR UPDATE ON activities
        FOR EACH ROW EXECUTE PROCEDURE code_to_upper()/,

    q/-- intervals
      CREATE TABLE intervals (
          iid        serial PRIMARY KEY,
          eid        integer REFERENCES employees (eid) NOT NULL,
          aid        integer REFERENCES activities (aid) NOT NULL,
          intvl      tsrange NOT NULL,
          long_desc  text,
          remark     text,
          EXCLUDE USING gist (eid WITH =, intvl WITH &&)
      )/,

    q/-- trigger function to make 'iid' field immutable
    CREATE OR REPLACE FUNCTION iid_immutable() RETURNS trigger AS $IMM$
      BEGIN
          IF OLD.iid <> NEW.iid THEN
              RAISE EXCEPTION 'intervals.iid field is immutable'; 
          END IF;
          RETURN NEW;
      END;
    $IMM$ LANGUAGE plpgsql/,
    
    q/-- trigger the trigger
    CREATE TRIGGER no_iid_update BEFORE UPDATE ON intervals
      FOR EACH ROW EXECUTE PROCEDURE iid_immutable()/,
    
    q/-- locks
      CREATE TABLE locks (
          lid     serial PRIMARY KEY,
          eid     integer REFERENCES Employees (EID),
          intvl   tsrange NOT NULL,
          remark  text,
          EXCLUDE USING gist (eid WITH =, intvl WITH &&)
      )/,

    q/-- trigger function to make 'lid' field immutable
    CREATE OR REPLACE FUNCTION lid_immutable() RETURNS trigger AS $IMM$
      BEGIN
          IF OLD.lid <> NEW.lid THEN
              RAISE EXCEPTION 'locks.lid field is immutable'; 
          END IF;
          RETURN NEW;
      END;
    $IMM$ LANGUAGE plpgsql/,
    
    q/-- trigger the trigger
    CREATE TRIGGER no_lid_update BEFORE UPDATE ON locks
      FOR EACH ROW EXECUTE PROCEDURE lid_immutable()/,
    
    q/-- insert root employee into employees table and grant admin
      -- privilege to the resulting EID
      WITH cte AS (
        INSERT INTO employees (nick, fullname, email, passhash, remark) 
        VALUES ('root', 'Root Immutable', 'root@site.org', 'immutable', 'dbinit') 
        RETURNING eid
      ) 
      INSERT INTO privhistory (eid, priv, effective, remark)
      SELECT eid, 'admin', '1000-01-01', 'IMMUTABLE' FROM cte
    /,

    q/-- insert demo employee into employees table
      INSERT INTO employees (nick, fullname, email, passhash, remark) 
      VALUES ('demo', 'Demo Employee', 'demo@dochazka.site', 'demo', 'dbinit') 
      RETURNING eid
    /,

]);

# DBINIT_SELECT_EID_OF_ROOT
#   after create_tables (REST.pm) executes the above list of SQL
#   statements, it needs to find the EID of the root employee
#
set('DBINIT_SELECT_EID_OF_ROOT', q/
    SELECT eid FROM employees WHERE nick = 'root'/);

# DBINIT_MAKE_ROOT_IMMUTABLE
#   after finding the EID of the root employee, create_tables executes
#   another batch of SQL statements to make root immutable
#   (for more information, see t/002-root.t)
#
set('DBINIT_MAKE_ROOT_IMMUTABLE', [

    q/
    -- trigger function to detect attempts to change nick of the
    -- root employee
    CREATE OR REPLACE FUNCTION root_immutable() RETURNS trigger AS $IMM$
      BEGIN
          IF OLD.eid = ? THEN
              IF NEW.nick <> 'root' THEN
                  RAISE EXCEPTION 'root employee is immutable'; 
              END IF;
          END IF;
          RETURN NEW;
      END;
    $IMM$ LANGUAGE plpgsql/,
    
    q/
    -- this trigger makes it impossible to update the root employee
    CREATE TRIGGER no_root_change BEFORE UPDATE ON employees
      FOR EACH ROW EXECUTE PROCEDURE root_immutable()/,
    
    q/
    CREATE OR REPLACE FUNCTION root_immutable_new() RETURNS trigger AS $IMM$
      BEGIN
          IF NEW.eid = ? THEN
              RAISE EXCEPTION 'root employee is immutable'; 
          END IF;
          RETURN NEW;
      END;
    $IMM$ LANGUAGE plpgsql/,
    
    q/
    CREATE OR REPLACE FUNCTION root_immutable_old() RETURNS trigger AS $IMM$
      BEGIN
          IF OLD.eid = ? THEN
              RAISE EXCEPTION 'root employee is immutable'; 
          END IF;
          RETURN OLD;
      END;
    $IMM$ LANGUAGE plpgsql/,

    q/
    -- this trigger makes it impossible to delete the root employee
    CREATE TRIGGER no_root_delete BEFORE DELETE ON employees
      FOR EACH ROW EXECUTE PROCEDURE root_immutable_old()/,
    
    q/
    -- this trigger makes it impossible to insert any new privhistory 
    -- rows for the root employee
    CREATE TRIGGER no_root_new BEFORE INSERT ON privhistory
      FOR EACH ROW EXECUTE PROCEDURE root_immutable_new()/,
    
    q/
    -- this trigger makes it impossible to update or delete the root
    -- employee's privhistory row
    CREATE TRIGGER no_root_old BEFORE UPDATE OR DELETE ON privhistory
      FOR EACH ROW EXECUTE PROCEDURE root_immutable_old()/,
    
]);


# -----------------------------------
# DO NOT EDIT ANYTHING BELOW THIS LINE
# -----------------------------------
use strict;
use warnings;

1;
