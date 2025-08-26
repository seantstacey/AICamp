-- Connect to ADB23ai AlwaysFree - (NON-partnersas) 

select banner_full from v$version ;
select cloud_identity from v$containers ;

begin
  dbms_cloud_ai.create_profile(

  profile_name => 'myprofile',
  attributes =>       
      '{"provider": "openai",
        "credential_name": "OPENAI_CRED",
        "comments":"true",
        "object_list": [
          {"owner": "admin"}
        ]          
        }'
  );
end;
/

-- ------------------------------------------------------------
--  Synthetic Data Generation Demo
-- 
--   This Demo uses OpenAI to generate synthetic data, but can 
--   also be used with other LLMs. 
-- ------------------------------------------------------------

--  To drop an existing profile- 
-- EXECUTE dbms_cloud_ai.drop_profile('myprofile')  ;


-- -----------------------------------------------------------------------------------
-- 1. Setup ACL to access OpenAI 
-- -----------------------------------------------------------------------------------

BEGIN
DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE (
  HOST         => 'api.openai.com',
  LOWER_PORT   => 443,
  UPPER_PORT   => 443,
  ACE          => xs$ace_type(
      PRIVILEGE_LIST => xs$name_list('http'),
      PRINCIPAL_NAME => 'ADMIN',
      PRINCIPAL_TYPE => xs_acl.ptype_db));
END;
/


-- -----------------------------------------------------------
-- 2. Permit the ADMIN user to call the DBMS_CLOUD_AI package 
-- -----------------------------------------------------------

GRANT EXECUTE ON DBMS_CLOUD_AI TO ADMIN
/


-- -----------------------------------------------------
-- 3. Set OpenAI Token for authenticating to OpenAI
-- -----------------------------------------------------

BEGIN
    dbms_cloud.create_credential (
        credential_name  => 'OPENAI_CRED',
        username => 'OPENAI',
        password => '<my openAI token>'
    );
END;
/


-- -----------------------------------------------------
-- 4. The preceding steps only need to be setup once.
--    The following steps are all that is required to
--    generate synthetic data. 
-- -----------------------------------------------------

exec  dbms_cloud_ai.set_profile(profile_name => 'myprofile');

drop table if exists STREET_ADDRESS purge; 

create table STREET_ADDRESS (address varchar2(40), city varchar2(40), country varchar2(40) ) ;

-- Optional step...
comment on table  street_address is 'Contains street addresses ';
comment on column street_address.address is 'Number and street name for address';
comment on column street_address.city is 'City for address';
comment on column street_address.country is 'Country for address';


BEGIN
  DBMS_CLOUD_AI.generate_synthetic_data(
    profile_name => 'myprofile',
    object_name  => 'Street_Address',
    owner_name   => 'ADMIN',
    record_count => 5,
    user_prompt  => 'Street address'
  );
END;

commit ;       
select * from STREET_ADDRESS ;


set timing on
BEGIN
  DBMS_CLOUD_AI.generate_synthetic_data(
    profile_name => 'myprofile',
    object_name  => 'Street_Address',
    owner_name   => 'ADMIN',
    record_count => 5,
    user_prompt  => 'Street address in France'
  );
END;

commit ;   

-- Sample user prompts I've used:
    user_prompt  => 'Lengthy description of a medical condition using at least 30 words but no more than 50 words.'
    user_prompt  => 'Random alphanumerical code for a student id formatted as 4 segments seperated with a dash.'
    user_prompt  => 'Random phone numbers with US area codes in north carolina, california and massachusetts and random email addresses and state code for the same area code'
