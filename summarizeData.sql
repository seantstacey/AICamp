select sysdate 
set lines 175
-- -------------------------------------------------------------------------------------------------
-- 
-- Demonstrate dbms_vector_chain.utl_to_summary
-- 
-- takes a string and summarizes it using a third party genAi model
-- 
--  doc link: 
--    https://docs.oracle.com/en/database/oracle/oracle-database/23/vecse/generate-summary-using-public-third-party-apis.html
--
--  NOTE: Two versions of the code... Both use PLSQL blocks 
--
-- Medical example.
-- The detailed description was taken from: 
--   https://www.hopkinsmedicine.org/health/treatment-tests-and-therapies/angioplasty-and-stent-placement-for-the-heart 
-- 

-- -------------------------------------------------------------------------------------------------
-- Demos:
--   1. PLSQL block is summarized running inside the database (No LLM) 
--   2. PLSQL block summarizes text - using medical description.
--   3. PLSQL block summarizes text - using Oracle documentation sample.
--   4. PLSQL block summarizes text taken from a CLOB entry in a table.
--   5. SQL statement summarizes text taken from a CLOB entry stored in a table. 
--   6. Asks the LLM a question using DBMS_VECTOR_CHAIN. 
-- -------------------------------------------------------------------------------------------------


-- Demo 1. PLSQL block summarizes text - using medical description (NO LLM)
--         Note: in this example the Database is the inference engine.
-- -------------------------------------------------------------------------------------------------


set serveroutput on

declare 
  params clob ;
  outputString clob ;
begin
   select '{ "provider"        : "database",
             "glevel"          : "sentence",
             "numParagraphs"   : 1
            }' 
   into params;

   -- dbms_output.put_line(' Params: '||params ) ;

   select dbms_vector_chain.utl_to_summary(
      'Angioplasty is a procedure used to open blocked coronary arteries caused by coronary artery disease. It restores blood flow to the heart 
      muscle without open-heart surgery. Angioplasty can be done in an emergency setting, such as a heart attack. Or it can be done as elective 
      surgery if your healthcare provider strongly suspects you have heart disease. Angioplasty is also called percutaneous coronary intervention.
      For angioplasty, a long, thin tube (catheter) is put into a blood vessel. It is then guided to the blocked coronary artery. The catheter has
      a tiny balloon at its tip. Once the catheter is in place, the balloon is inflated at the narrowed area of the heart artery. This presses the
      plaque or blood clot against the sides of the artery. The result is more room for blood flow.
      The healthcare provider uses fluoroscopy during the surgery. Fluoroscopy is a special type of X-ray that’s like an X-ray "movie." It helps 
      the healthcare provider find the blockages in the heart arteries as a contrast dye moves through the arteries. This is called coronary 
      angiography.
      The healthcare provider may decide that you need another type of procedure. This may include removing the plaque (atherectomy) at the site 
      of the narrowing of the artery. In atherectomy, the healthcare provider may use a catheter with a rotating tip. The plaque is broken up or 
      cut away to open the artery once the catheter reaches the narrowed spot in the artery.', 
  json(params)) 
  into outputString ;

  dbms_output.put_line(' outputString: '||outputString ) ;

end ; 

-- Demo 2. PLSQL block summarizes text - using medical description
--         Note: in this example the ai parameters are parsed using SELECT INTO statement.
-- -------------------------------------------------------------------------------------------------

set lines 200

set serveroutput on

declare 
  params clob ;
  outputString clob ;
begin
   select '{ "provider"        : "openai",
             "credential_name" : "OPENAI_CRED",
             "url"             : "https://api.openai.com/v1/chat/completions",
             "model"           : "gpt-4o-mini",
             "max_tokens"      : 256,
             "temperature"     : 1.0
            }' 
   into params;

   -- dbms_output.put_line(' Params: '||params ) ;

   select dbms_vector_chain.utl_to_summary(
      'Angioplasty is a procedure used to open blocked coronary arteries caused by coronary artery disease. It restores blood flow to the heart 
      muscle without open-heart surgery. Angioplasty can be done in an emergency setting, such as a heart attack. Or it can be done as elective 
      surgery if your healthcare provider strongly suspects you have heart disease. Angioplasty is also called percutaneous coronary intervention.
      For angioplasty, a long, thin tube (catheter) is put into a blood vessel. It is then guided to the blocked coronary artery. The catheter has
      a tiny balloon at its tip. Once the catheter is in place, the balloon is inflated at the narrowed area of the heart artery. This presses the
      plaque or blood clot against the sides of the artery. The result is more room for blood flow.
      The healthcare provider uses fluoroscopy during the surgery. Fluoroscopy is a special type of X-ray that’s like an X-ray "movie." It helps 
      the healthcare provider find the blockages in the heart arteries as a contrast dye moves through the arteries. This is called coronary 
      angiography.
      The healthcare provider may decide that you need another type of procedure. This may include removing the plaque (atherectomy) at the site 
      of the narrowing of the artery. In atherectomy, the healthcare provider may use a catheter with a rotating tip. The plaque is broken up or 
      cut away to open the artery once the catheter reaches the narrowed spot in the artery.', 
  json(params)) 
  into outputString ;

  dbms_output.put_line(' outputString: '||outputString ) ;

end ; 



-- -------------------------------------------------------------------------------------------------
-- Demo 3. PLSQL block summarizes text - using Oracle documentation sample
--         Note: in this example the ai parameters are parsed as a variable.
-- -------------------------------------------------------------------------------------------------

set serveroutput on

declare
  input clob;
  params clob;
  output clob;
begin
  input := 'A transaction is a logical, atomic unit of work that contains one or more SQL
    statements.
    An RDBMS must be able to group SQL statements so that they are either all
    committed, which means they are applied to the database, or all rolled back, which
    means they are undone.
    An illustration of the need for transactions is a funds transfer from a savings account to
    a checking account. The transfer consists of the following separate operations:
    1. Decrease the savings account.
    2. Increase the checking account.
    3. Record the transaction in the transaction journal.
    Oracle Database guarantees that all three operations succeed or fail as a unit. For
    example, if a hardware failure prevents a statement in the transaction from executing,
    then the other statements must be rolled back.
    Transactions set Oracle Database apart from a file system. If you
    perform an atomic operation that updates several files, and if the system fails halfway
    through, then the files will not be consistent. In contrast, a transaction moves an
    Oracle database from one consistent state to another. The basic principle of a
    transaction is "all or nothing": an atomic operation succeeds or fails as a whole.';

  params := '{ "provider"        : "openai",
               "credential_name" : "OPENAI_CRED",
               "url"             : "https://api.openai.com/v1/chat/completions",
               "model"           : "gpt-4o-mini",
               "max_tokens"      : 256,
               "temperature"     : 1.0
          }';

  output := dbms_vector_chain.utl_to_summary(input, json(params));

  dbms_output.put_line(output);
  if output is not null then
    dbms_lob.freetemporary(output);
  end if;
exception
  when OTHERS THEN
    DBMS_OUTPUT.PUT_LINE (SQLERRM);
    DBMS_OUTPUT.PUT_LINE (SQLCODE);
end;
/



-- -------------------------------------------------------------------------------------------------
-- Demo 4. PLSQL block summarizes text taken from a CLOB entry in a table
-- -------------------------------------------------------------------------------------------------

set serveroutput on
set lines 120

declare 
  params clob ;
  outputString clob ;
begin
   params := '{ "provider"        : "openai",
                "credential_name" : "OPENAI_CRED",
                "url"             : "https://api.openai.com/v1/chat/completions",
                "model"           : "gpt-4o-mini",
                "max_tokens"      : 256,
                "temperature"     : 1.0
              }' ;

   -- dbms_output.put_line(' Params: '||params ) ;

select dbms_vector_chain.utl_to_summary((select text from blob_tab where id = 4), json(params)) 
  into outputString ;

  dbms_output.put_line(' outputString: '||outputString ) ;

end ; 

col title form A30
col filename form A30
select id, title, filetype, filename, text_length from blob_tab where id = 4;


-- -------------------------------------------------------------------------------------------------
-- Demo 5. SQL statement summarizes text taken from a CLOB entry stored in a table
--         Note: In this example the ai parameters are parsed with the call to utl_to_summary.
-- -------------------------------------------------------------------------------------------------

select dbms_vector_chain.utl_to_summary((select text from blob_tab where id = 4), 
                                         json('{ "provider"        : "openai",
                                                 "credential_name" : "OPENAI_CRED",
                                                 "url"             : "https://api.openai.com/v1/chat/completions",
                                                 "model"           : "gpt-4o-mini",
                                                 "max_tokens"      : 256,
                                                 "temperature"     : 1.0  }')) "AI Summary" ;
 


-- -------------------------------------------------------------------------------------------------
-- Demo 6. Asks the LLM a question using DBMS_VECTOR_CHAIN. 
--         Note: In this example the ai parameters are parsed with the call to utl_generate_text.
-- -------------------------------------------------------------------------------------------------

select dbms_vector_chain.utl_to_generate_text( 'What is Oracle Text?', 
                                               json('{ "provider"        : "openai",
                                                       "credential_name" : "OPENAI_CRED",
                                                       "url"             : "https://api.openai.com/v1/chat/completions",
                                                       "model"           : "gpt-4o-mini",
                                                       "max_tokens"      : 256,
                                                       "temperature"     : 1.0  }')) "AI Response";

