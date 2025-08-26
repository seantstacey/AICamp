-- Connect to ADB23ai AlwaysFree  

select banner_full from v$version ;
select cloud_identity from v$containers ;

-- -------------------------------------------------------------------------
-- 1. Create a credential to access an OCI Object Storage Bucket.
-- -------------------------------------------------------------------------

BEGIN
    dbms_cloud.create_credential (
        credential_name  => 'OCI_BKT_CRED',
        username => '<oci username>',
        password => '<passwd>'
    );
END;
/

-- Verify the credential exists and is enabled
select credential_name, comments, enabled from user_credentials ;


-- -------------------------------------------------------------------------
-- 2. Query the contents of the Object Storage Bucket for ONNX files
-- -------------------------------------------------------------------------

-- View contents of Cloud Storage Bucket
SELECT object_name, bytes
FROM  DBMS_CLOUD.LIST_OBJECTS('OCI_BKT_CRED', 'https://<service-name>/n/<tenancy>/b/<bucket-name>/o/')
WHERE  object_name like '%onnx%';


-- -------------------------------------------------------------------------
-- 3. Load the ONNX model into the database
-- -------------------------------------------------------------------------

BEGIN
    dbms_vector.load_onnx_model_cloud(
       model_name => 'allminiLML12',
       credential => 'OCI_BKT_CRED', 
       uri => 'https://<service-name>/n/<tenancy>/b/<bucket-name>/o/all_MiniLM_L12_v2.onnx',
       metadata => JSON('{"function" : "embedding", "embeddingOutput" : "embedding" , "input": {"input": ["DATA"]}}')
    );
END ;
/

-- ALTERNATE APPROACH FOR RUNNING ON LOCAL SERVER (NON-AUTONOMOUS)
BEGIN
   DBMS_VECTOR.LOAD_ONNX_MODEL(
      directory  => 'VEC_DUMP',
      file_name  => 'all_MiniLM_L12_v2.onnx',
      model_name => 'allminiLML12',
      metadata => JSON('{"function" : "embedding", "embeddingOutput" : "embedding", "input": {"input": ["DATA"]}}')
    );
END;
/


-- Verify the Model has been imported
-- ----------------------------------

SELECT * FROM user_mining_models ;
SELECT * FROM user_mining_model_attributes where data_type = 'VECTOR' ; 

select vector_embedding(allMiniLMl12 USING 'Hello!' as data) AS embedding;

-- -------------------------------------------------------------------------
-- 4. Vectorize data using the imported ONNX model
-- -------------------------------------------------------------------------

-- Demo- Source table containing factoids  
SELECT * FROM factoids order by 1

DROP TABLE IF EXISTS my_data purge ;

-- Create new table using the Source table and embedding/vectorizing the factoids with the imported ONNX model
create table my_data as
   select id, info, 
          vector_embedding(allMiniLMl12 using f.info as data) as vect
   from  factoids f
   order by id;

-- Display new table with Vectors
select * from my_data order by 1

-- Run Similarity Search against the data set
select id, info
from   my_data
order  by vector_distance(vect, vector_embedding(allMiniLMl12 using :input_string as data), cosine)
fetch first 5 rows only;


