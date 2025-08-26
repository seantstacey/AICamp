-- Setup in: freepdb1 : NationalParks Connection
-- Connect to NationalParks (non-ADB) to use FREEPDB1 instance

select banner_full from v$version ;
select name, cloud_identity from v$containers ;

select sid from v$instance ;

col dir_name form A20
col dir_path form A50
col model_name form A30
col attribute_name form A20
col data_type form A25
col vector_info form A30

-- grant CREATE mining model to vector ;
-- grant EXECUTE on dbms_cloud_ai to vector ;
-- drop mining model clipvit_base_patch32 ;

-- Steps in this file:
-- ONNX Model 1. create the OCI credential
--            2. query the Directory where the model is located
--            3. load the onnx model
--            4. check the onnx model is loaded
--            5. Check that the model works
--            6. Load sample images from Object Storage Bucket
--            7. Display IMAGE_VECTOR table to see the vectors
--            8. Main Vector Similarity Search operation
--
-- -------------------------------------------------------------------------
-- 1. Create a credential to access external urls from the database.
--    - needs to be run with appropriate privileges
-- -------------------------------------------------------------------------

BEGIN
   DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE (
     HOST         => '*',
     LOWER_PORT   => 443,
     UPPER_PORT   => 443,
     ACE          => xs$ace_type(
         PRIVILEGE_LIST => xs$name_list('http'),
         PRINCIPAL_NAME => 'NATIONALPARKS',
         PRINCIPAL_TYPE => xs_acl.ptype_db));
END;
/


-- -------------------------------------------------------------------------
-- 2. Query the contents of the DIRECTORY for the any ONNX files
-- -------------------------------------------------------------------------

-- This step would be run by a different user with DBA privs
-- create or replace directory VEC_DUMP as '/opt/oracle/myBucket/';
-- grant read, write on directory vec_dump to vector;


SELECT substr(directory_name,1,20) dir_name,
       substr(directory_path,1,50) dir_path
FROM   all_directories ;


-- -------------------------------------------------------------------------
-- 3. Load the Vision Transformer ONNX model into the database
-- -------------------------------------------------------------------------

EXEC DBMS_VECTOR.DROP_ONNX_MODEL(model_name => 'CLIPVIT_BASE_PATCH32', force => true);
EXEC DBMS_VECTOR.DROP_ONNX_MODEL(model_name => 'CLIPVIT_BASE_PATCH32_TXT', force => true);
EXEC DBMS_VECTOR.DROP_ONNX_MODEL(model_name => 'ALLMINILML12', force => true);

BEGIN
   dbms_vector.load_onnx_model(
      directory  => 'VEC_DUMP',
      file_name  => 'all_MiniLM_L12_v2.onnx',
      model_name => 'allMiniLML12',
      metadata => JSON('{"function" : "embedding", "embeddingOutput" : "embedding" , "input": {"input": ["DATA"]}}')
    );
END ;
/

BEGIN
   dbms_vector.load_onnx_model(
      directory  => 'VEC_DUMP',
      file_name  => 'clip-vit-base-patch32_img.onnx',
      model_name => 'CLIPVIT_BASE_PATCH32',
      metadata => JSON('{"function" : "embedding", "embeddingOutput" : "embedding", "input": {"input": ["DATA"]}}'));
END;
/

BEGIN
   dbms_vector.load_onnx_model(
      directory  => 'VEC_DUMP',
      file_name  => 'clip-vit-base-patch32_txt.onnx',
      model_name => 'CLIPVIT_BASE_PATCH32_TXT',
      metadata => JSON('{"function" : "embedding", "embeddingOutput" : "embedding", "input": {"input": ["DATA"]}}'));
END;
/

-- -------------------------------------------------------------------------
-- 4. Verify the Model has been imported
-- -------------------------------------------------------------------------

SELECT model_name,
       attribute_type,
       data_type, vector_info
FROM   user_mining_model_attributes
WHERE  attribute_type = 'VECTOR'
/

SELECT model_name,
       mining_function,
       algorithm,
       algorithm_type,
       model_size
FROM   user_mining_models
-- WHERE  model_name = 'CLIPVIT_BASE_PATCH32';

select vector_embedding(allMiniLMl12 USING 'Hello!' as data) AS embedding;

-- -------------------------------------------------------------------------
-- 5. Create Vector table:PARK_VECTOR for National Park Descriptions
-- -------------------------------------------------------------------------

drop table if exists park_vector purge ;

create table if not exists park_vector as 
   select p.park_code, 
          p.park_id, 
          vector_embedding(AllMiniLML12 using p.description as data) as park_vect
   from  parks p
   order by p.park_code;


-- -------------------------------------------------------------------------
-- 6. Perform Similarity Search on park descriptions
-- -------------------------------------------------------------------------

-- Query the PARK_VECTOR using a Vector Similarity Search
select pv.park_code, pv.park_vect
from   park_vector pv
order  by vector_distance(pv.park_vect, vector_embedding(allMiniLMl12 using :input_keyword as data), cosine)
fetch first 10 rows only;


-- Try input_keyword "volcano"
-- Notice: 
--   1. This query joins two tables to perform a filter operation
--   2. Park code: the Description for "sucr" does not directly include the word "volcano" yet it appears. in our search 
select p.park_code, p.name, p.states, p.description  
from   parks p, park_vector pv
where  p.park_code = pv.park_code
order  by vector_distance(pv.park_vect, vector_embedding(allMiniLMl12 using :input_keyword as data), cosine)
fetch first 10 rows only


-- ----------------------------------------------------------------------------
-- 7. TEXT-based Similarity Search of Image_Vectors using an input text-string.
-- ----------------------------------------------------------------------------

-- Pre-Setup for browser for demo - use RunScript button:    
  select url from park_images order by vector_distance(image_vector, vector_embedding(CLIPVIT_BASE_PATCH32_TXT USING 'Sagauro' as data)) fetch first 1 rows only;

  select pi.image_id, pi.url, pi.title, pi.file_name, pi.park_code
  from   park_images pi
  order  by vector_distance(pi.image_vector, vector_embedding(CLIPVIT_BASE_PATCH32_TXT USING :textString as data)) 
  fetch first 10 rows only;


-- -------------------------------------------------------------------------
-- 8. Perform IMAGE Similarity Search on park a supplied image
-- -------------------------------------------------------------------------

-- Find 10 closest image matches based on a similarity search for pre-canned vector..
-- Humpback Whale breaching - 3 diff parks in 10 images or 4 in 15
-- -> cut+paste input_vector -> 
 [2.49980956E-001,-4.18444544E-001,-1.78864449E-002,-1.35611802E-001,3.59122902E-001,-1.88329279E-001,3.51727813E-001,1.4236936E-001,1.07532072E+000,2.42571622E-001,-3.29190418E-002,-4.53154683E-001,3.83001089E-001,-3.93018007E-001,-1.5545477E-001,-1.92637965E-001,-7.10996747E-001,1.89218566E-001,6.03806853E-001,3.35017979E-001,-1.35177243E+000,3.46538007E-001,1.52573675E-001,-1.91250265E-001,2.52942711E-001,3.19548666E-001,-5.22442907E-002,-5.30069023E-002,1.57438144E-001,-3.78016621E-001,-3.97789747E-001,9.4043918E-002,-1.68552458E-001,-1.10665284E-001,2.25869253E-001,5.45589402E-002,-1.61324605E-001,-6.6267848E-002,4.25476044E-001,1.70648229E+000,-5.67121655E-002,2.51423195E-002,2.0072639E-001,-1.72101051E-001,-2.79053718E-001,-1.06286085E+000,4.10022914E-001,1.08378403E-001,-1.44809008E-001,-4.99612801E-002,-4.61192369E-001,-3.11145429E-002,3.79703403E-001,-3.88450384E-001,6.86056726E-003,5.87416708E-001,-3.00789714E-001,3.87764335E-001,6.3374728E-002,4.05481756E-002,1.7331183E-001,-2.82449245E-001,-1.93020403E-001,-1.00623533E-001,-4.86709997E-002,6.58664107E-002,7.51999766E-002,3.79914045E-001,2.80090243E-001,-1.47660911E-001,4.52700645E-001,-2.10075051E-001,-2.23387554E-001,-1.58659481E-002,2.70314872E-001,-2.78991282E-001,1.5802604E-001,-3.20290655E-001,8.1233032E-002,-2.77910411E-001,3.97794545E-001,-7.73309693E-002,-8.17801133E-002,-2.52128273E-001,1.66255474E-001,-1.65077016E-001,2.09324867E-001,-2.09203482E-001,-7.85554387E-003,-1.11250784E-002,5.49112022E-001,-2.92652488E-001,-6.64312649E+000,-1.26498595E-001,-4.57304686E-001,4.96628106E-001,3.97026122E-001,-1.26505464E-001,-2.91358471E-001,-1.32053685E+000,1.09574469E-002,-8.30037236E-001,-1.14600396E+000,6.26760125E-002,3.22458595E-002,2.11690307E-001,-1.91653192E+000,2.09070727E-001,-6.64969161E-002,7.8808248E-002,1.0280548E-001,-3.88131768E-001,4.53724146E-001,-2.67751634E-001,4.28180784E-001,-6.0696727E-001,-5.30711077E-002,-3.04042816E-001,2.95015454E-001,-2.35800855E-002,-2.76818156E-001,2.69880623E-001,1.63242131E-001,-3.41119051E-001,-1.87182128E-001,-3.91761452E-001,-2.12628275E-001,4.75524932E-001,6.6963926E-002,-1.37835115E-001,1.67778164E-001,-5.14536858E-001,-5.29556453E-001,7.9004693E-001,-3.54314566E-001,-2.10681349E-001,3.21122766E-001,-8.39494407E-001,-1.79728627E-001,-2.34622344E-001,-2.4858579E-002,-5.81084907E-001,2.96376824E-001,1.02440394E-001,2.41223782E-001,1.27032578E-001,-9.13704485E-002,2.01159149E-001,-5.08239493E-002,-1.40144899E-001,7.10268676E-001,3.33543777E-001,-3.27626705E-001,-1.35069996E-001,1.4544788E-001,-7.05836713E-001,4.46048856E-001,1.56803221E-001,-4.80054229E-001,-1.2361899E-002,-4.84694391E-001,-6.01975322E-001,-1.10651299E-001,2.62330532E-001,7.29968309E-001,-1.95797998E-002,2.91878223E-001,2.02801704E-001,2.79899854E-002,2.87980307E-002,1.10747382E-001,2.4520655E-001,2.89690316E-001,-7.61618465E-002,-5.16475379E-001,-1.43272415E-001,-2.79482275E-001,9.12718326E-002,-6.86390579E-001,-6.87832534E-002,4.30565983E-001,2.44425297E-001,2.45349482E-001,8.57908279E-002,4.08728182E-001,2.18416333E-001,1.10954143E-001,-1.14581741E-001,-9.25329551E-002,-1.80607915E-001,-6.48121387E-002,-8.76015127E-002,-1.55570582E-001,4.45211828E-001,-5.5092752E-002,-1.44141808E-001,-3.63857836E-001,-3.76244821E-003,3.3951661E-001,-4.41151112E-002,1.43516019E-001,-4.28715982E-002,-3.05787474E-001,1.55846238E-001,2.92442173E-001,5.73258586E-002,-3.9780286E-001,9.0088889E-002,1.2873064E-001,2.15258598E-001,3.62049669E-001,6.63327098E-001,2.27289289E-001,-4.91742268E-002,1.39390707E-001,7.38770068E-002,2.9725951E-001,3.78434837E-001,3.6049217E-002,1.0591083E-001,3.16585958E-001,-2.46336699E-001,3.14969301E-001,1.90361619E-001,4.47217733E-001,-3.40299681E-002,-6.54349998E-002,4.31141287E-001,3.64490263E-002,2.55483955E-001,2.91034997E-001,-1.61402822E-001,1.65088121E-002,1.89320087E-001,5.19427061E-001,-9.21940267E-001,1.44142836E-001,7.50403404E-002,-1.37700036E-001,2.70100564E-001,4.82607037E-002,2.00967133E-001,4.09648329E-001,-1.22454539E-001,1.29912868E-001,1.9791387E-001,8.92930776E-002,2.52384305E-001,2.22788043E-002,2.63768137E-001,-3.66025418E-001,6.26478851E-001,1.01050645E-001,7.93770328E-002,-6.41850114E-001,8.50124732E-002,1.8872568E-001,2.58025616E-001,2.05857611E+000,3.28675136E-002,3.84367593E-002,2.38854483E-001,-1.55901864E-001,1.66405946E-001,2.41493344E-001,-4.24872078E-002,2.93307066E-001,-7.27363601E-002,3.3646512E-001,7.39530697E-002,8.55055302E-002,1.97978884E-001,4.60458361E-003,4.14882451E-002,3.65038157E-001,-3.28090072E-001,1.33299798E-001,9.49560404E-002,-4.58060764E-002,-4.82599676E-001,2.40734577E-001,-1.94154024E-001,1.76452547E-001,6.57511577E-002,6.34346604E-001,3.53900462E-001,-1.12061429E+000,-2.66685754E-001,-1.37730807E-001,-1.97697207E-001,1.91135749E-001,3.73313092E-002,7.40582347E-002,5.72517291E-002,1.29807949E-001,4.35448349E-001,8.3350575E-001,1.30908906E-001,-1.93732083E-001,5.94547331E-001,5.41101471E-002,-6.50912046E-001,5.46583533E-001,-3.13531131E-001,3.85205656E-001,9.42596048E-002,1.47004187E-001,1.34784713E-001,5.34598589E-001,4.51232195E-001,-7.48987794E-002,1.59912512E-001,7.89286494E-001,2.12166339E-001,1.92217216E-001,-1.33733556E-001,6.68789029E-001,5.78536689E-001,1.56193748E-001,-9.75847691E-002,7.82784522E-001,2.64165044E-001,4.87314641E-001,-5.48050553E-003,2.91280538E-001,-6.49736226E-001,-2.78318226E-001,-5.52616119E-002,-2.61947185E-001,-7.79727772E-002,-3.16063732E-001,-4.88142818E-001,2.01860547E-001,3.36361378E-002,-2.36661851E-001,3.10413353E-002,-1.57470122E-001,1.45069659E-001,-2.54775703E-001,2.34088436E-001,-4.24374163E-001,7.83750787E-002,-1.2101154E-001,-9.68300253E-002,-2.97801703E-001,-2.32577875E-001,9.37834755E-002,-2.67081767E-001,-7.72183761E-004,4.26627785E-001,-3.38629276E-001,2.09289595E-001,1.41055599E-001,1.46539524E-001,-1.46224931E-001,3.18993539E-001,2.45956197E-001,-3.89934897E-001,4.45094794E-001,2.65850246E-001,2.96765625E-001,2.88303554E-001,4.28571612E-001,4.93896008E-001,-2.30269372E-001,2.86900222E-001,1.31689072E-001,-1.33845496E+000,-3.52130502E-001,4.07138467E-003,-2.24665925E-002,6.02695644E-001,4.08701062E-001,-3.42979692E-002,2.5203824E-001,-3.57009441E-001,1.21742773E+000,3.09140414E-001,-4.94786084E-001,-2.0756425E-001,1.19842306E-001,-1.49660453E-001,-8.88270587E-002,-3.74367833E-001,7.91954026E-002,5.63754261E-001,2.59707481E-001,1.23336948E-001,-1.75511673E-001,-1.14797795E+000,3.67022216E-001,-2.18584493E-001,6.91954434E-001,-7.63406605E-002,-6.92881167E-001,-3.68479222E-001,-5.18359661E-001,4.71958667E-001,-1.14805734E+000,-1.25237629E-001,5.76819554E-002,7.93775544E-002,-4.82093304E-001,-1.33254886E-001,-3.11553001E-001,-2.6697582E-001,3.76208007E-001,-4.10800934E-001,9.27432701E-002,1.22653209E-002,1.18807328E+000,5.20817101E-001,-4.76714492E-001,2.19719678E-001,-3.2374543E-001,-1.05674267E-002,-4.37000722E-001,-1.50969863E-001,2.5564146E-001,-2.62388825E-001,-8.46985206E-002,-3.52326989E-001,4.56742644E-002,-6.84251308E-001,-2.44374543E-001,-5.33461273E-001,-3.87681723E-001,4.18290854E-001,4.87480126E-003,-4.25575942E-001,2.03179836E-001,-1.87527202E-002,-2.69513965E-001,-5.42411506E-001,-7.07356036E-002,-2.87924528E-001,-3.07779443E-002,1.92122757E-001,-2.40806788E-002,-5.64877212E-001,7.55157471E-002,2.0156467E-001,-6.59822881E-001,4.5845598E-001,-1.78967685E-001,-4.79450613E-001,-3.46970081E-001,-8.05152431E-002,3.30152176E-002,-1.25153527E-001,2.95767114E-002,-3.7166357E-001,-1.53229296E-001,-1.18771307E-001,4.78492498E-001,-1.82909265E-001,-9.88471694E-003,-6.13527671E-002,1.67868063E-002,-4.89807934E-001,6.09166861E-001,2.42725551E-001,4.34082836E-001,3.46438885E-001,-1.01693086E-001,1.97989032E-001,4.61064547E-001,-1.90192297E-001,1.0085237E-001,6.80757361E-003,-7.3078163E-003,2.13558435E-001,-2.57098317E-001,-1.62675697E-002,2.53235996E-001,-1.9136098E-001,-3.99463326E-001,-1.02093592E-001,-7.8168422E-002,-5.00514805E-002,2.09426537E-001,-1.62793517E-001,2.93687552E-001,-3.03401083E-001,-4.3779593E-003,4.43528146E-001,9.23562981E-003,-6.89251944E-002,-4.21099633E-001,-2.28389218E-001,-2.46004164E-001,1.32682309E-001,5.06874681E-001,-7.21802473E-001,3.03675942E-002,-2.29114935E-001,-3.49186733E-003,5.71151555E-001,-6.1460191E-001,-3.44887301E-002,-5.63239217E-001,3.56977522E-001,-3.73680703E-002,5.20959198E-001,1.04136877E-001,-6.84435427E-001,-9.75513179E-003,1.28017709E-001,1.18885845E-001,3.18622053E-001,-3.14907432E-001,-9.71047133E-002]

select park_code
from   park_images pi
order  by vector_distance(pi.image_vector, :input_vector )
fetch first 10 rows only

select p.park_code, p.name, p.states, p.park_id, pi.image_id, pi.file_name, pi.url  
from   parks p, park_images pi
where  p.park_code = pi.park_code
order  by vector_distance(pi.image_vector, :input_vector)
fetch first 10 rows only

select * from park_images where image_id = '05F8934E-63ED-403F-A56E-FAE443F1D5D7'
select * from park_images where upper(title) like ('%HUMPBACK%') ;

create table natPk_output (image_id varchar2(36), url varchar2(75), title varchar2(257), file_name varchar2(46), park_code varchar2(4)) ;

-- 
-- AI Camp website- https://events.aicamp.ai/pingcap2023.html

set serveroutput on
declare 
   inblob blob;
   cursor C_output is select * from natPk_OUTPUT ;
   inurl  varchar2(150) :=  
--   'https://www.nps.gov/npgallery/GetAsset/05F8934E-63ED-403F-A56E-FAE443F1D5D7' ;    /* Whale */--
--   'https://www.nps.gov/npgallery/GetAsset/F5F3B4E6-155D-4519-3EF1-77881E0E3C71' ;    /* Bald Eagles */
--   'https://www.nps.gov/npgallery/GetAsset/431bb2bf-5478-4b79-9f56-866ffd19e216' ;    /* Waterfall */
--   'https://www.nps.gov/npgallery/GetAsset/7fb31e2c-182b-42e5-8905-400072bb9c6a' ;    /* Arch */ 
--   'https://www.nps.gov/npgallery/GetAsset/396670d0-6794-4304-802f-dfb4d3e925cb' ;    /* Geyser */
--   'https://dynamic-media.tacdn.com/media/photo-o/2e/d1/d0/d9/caption.jpg' ;          /* volcano - non natpark photo */
--   'https://d3d0lqu00lnqvz.cloudfront.net/media/media/834c4565-c71d-4a14-b711-5ee8f1acda64.jpg' ; /* Teepee - non natpark photo */
--   'https://as1.ftcdn.net/v2/jpg/05/88/89/70/1000_F_588897014_zGhy39F5vdLnbuyhzPqY02FmBzrLWJL3.jpg' ;  /* Pow wow */
   'https://events.aicamp.ai/assets/img/city/nyc.jpg' ;
begin
   delete from natPk_OUTPUT ;

   inblob := httpuritype.createuri(inurl).getblob(); 

   insert into natpk_output
     select pi.image_id, pi.url, pi.title, pi.file_name, pi.park_code
     from   park_images pi
     order  by vector_distance(pi.image_vector, vector_embedding(CLIPVIT_BASE_PATCH32 USING inblob as data)) 
     fetch first 10 rows only;

   for ci in C_output  loop
      dbms_output.put_line(' Image Id: '||ci.image_id ) ;
      dbms_output.put_line('Park Code: '||ci.park_code ) ;
      dbms_output.put_line('    Title: '||ci.title ) ;
      dbms_output.put_line('     File: '||ci.file_name ) ;
      dbms_output.put_line('      URL: '||ci.url ) ;
      dbms_output.put_line(' ') ;
   end loop;
   dbms_output.put_line('------------------------------' ) ;

end ;


