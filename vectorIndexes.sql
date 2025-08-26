select banner_full from v$version ;
select cloud_identity from v$containers ;

-- -----------------------------
-- CLEANUP
-- drop index MY_DATAXL_IVF_IDX
-- drop index MY_DATAXL_HNSW

set timing on

--  Table for Queries (Pre-Create Prior to running Demo)
-- -----------------------------------------------------
-- CREATE TABLE my_data_XL AS
--   SELECT cust_id id, cust_first_name firstname, cust_last_name lastname, cust_street_address streetaddress, 
--          vector_embedding(allMiniLMl12 using c.cust_first_name||' '||c.cust_last_name as data) as vect
--   FROM  customers c
--   ORDER BY cust_id;

-- exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> 'ADMIN', tabname=>'MY_DATA_XL', degree=> 2);

SELECT count(*) FROM MY_DATA_XL;

SELECT * FROM MY_DATA_XL 
FETCH FIRST 5 ROWS ONLY ;

set pages 200
-- -------------------------------------------------------------------------
-- 1. Run Explain Plan on non-Indexed table 
-- -------------------------------------------------------------------------

explain plan for
select id, firstname, lastname
from   MY_DATA_XL
order  by vector_distance(vect, vector_embedding(allMiniLMl12 using 'John Smith' as data), cosine)
fetch first 5 rows only;

select * from table(dbms_xplan.display)


-- -------------------------------------------------------------------------
-- 2. Create an IVF Flat Index  (and Gather Statistics)
-- -------------------------------------------------------------------------

CREATE VECTOR INDEX MY_DATAXL_IVF_IDX ON MY_DATA_XL (vect)  
ORGANIZATION NEIGHBOR PARTITIONS 
DISTANCE COSINE 
WITH TARGET ACCURACY 90; 

exec  DBMS_STATS.GATHER_INDEX_STATS (ownname=> 'ADMIN', indname=>'MY_DATAXL_IVF_IDX', degree=> 2);

BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS (ownname=> 'ADMIN', degree=> 2);
END;
/


-- -------------------------------------------------------------------------
-- 3. Run Explain Plan on table with IVF Flat Vector Index 
-- -------------------------------------------------------------------------
explain plan for
select id, firstname, lastname
from   MY_DATA_XL
order  by vector_distance(vect, vector_embedding(allMiniLMl12 using 'John Smith' as data), cosine)
fetch first 5 rows only;

select * from table(dbms_xplan.display)


-- -------------------------------------------------------------------------
-- 4. DROP IVF Flat Index  and Create HNSW INDEX
-- -------------------------------------------------------------------------

DROP INDEX MY_DATAXL_IVF_IDX ;  

-- -------------------------------------------------------------------------
-- 5. Check Vector Memory Pool for HNSW Index
-- -------------------------------------------------------------------------

select * from V$VECTOR_MEMORY_POOL

select CON_ID, 
       POOL, 
       ALLOC_BYTES/1024/1024 as ALLOC_BYTES_MB, 
       USED_BYTES/1024/1024 as USED_BYTES_MB
from  V$VECTOR_MEMORY_POOL 
order by 1,2;


-- -------------------------------------------------------------------------
-- 6. Create HNSW Index (and Gather Statistics)
-- -------------------------------------------------------------------------

CREATE VECTOR INDEX MY_DATAXL_HNSW ON MY_DATA_XL (vect)  
ORGANIZATION INMEMORY NEIGHBOR GRAPH
DISTANCE COSINE
WITH TARGET ACCURACY 90;
commit ;

exec  DBMS_STATS.GATHER_INDEX_STATS (ownname=> 'ADMIN', indname=>'MY_DATAXL_HNSW', degree=> 2);


-- -------------------------------------------------------------------------
-- 7. Run Explain Plan on table with HNSW Vector Index 
-- -------------------------------------------------------------------------
explain plan for
select id, firstname, lastname
from   MY_DATA_XL
order  by vector_distance(vect, vector_embedding(allMiniLMl12 using 'John Smith' as data), cosine)
fetch first 5 rows only;

select * from table(dbms_xplan.display)



-- -------------------------------------------------------------------------
-- 8. Determine memory required for HNSW Vector Index 
-- -------------------------------------------------------------------------

-- Approach 1: If you have not yet created a table with vectors.
-- --------------------------------------------------------------

set echo on
set termout on
set serveroutput on ;
declare 
  rsp_json clob ;
BEGIN
    dbms_vector.index_vector_memory_advisor(INDEX_TYPE => 'HNSW', 
                                             NUM_VECTORS => 55500, 
                                             DIM_COUNT => 384,
                                             DIM_TYPE => 'FLOAT32',
                                             PARAMETER_JSON => '{"neighbors":32}',
                                             RESPONSE_JSON => rsp_json) ;

    dbms_output.put_line(rsp_json);

end ; 
/


-- Approach 2: If you have an existing table with vectors created.
-- ---------------------------------------------------------------
declare
   resp_json clob;
BEGIN
  dbms_vector.index_vector_memory_advisor(TABLE_OWNER => 'ADMIN', 
                                          TABLE_NAME => 'MY_DATA_XL', 
                                          COLUMN_NAME => 'VECT', 
                                          INDEX_TYPE => 'HNSW', 
                                          PARAMETER_JSON => '{"neighbors":32}',
                                          RESPONSE_JSON => resp_json);

  dbms_output.put_line(resp_json);

end;


