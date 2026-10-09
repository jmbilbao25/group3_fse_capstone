-- Add geo-location and tracking columns to users table
SET SERVEROUTPUT ON;

DECLARE
  v_count NUMBER;
  v_pk_col VARCHAR2(64);
BEGIN
  SELECT COUNT(*) INTO v_count FROM user_tab_cols WHERE table_name = 'USERS' AND column_name = 'LAST_KNOWN_LATITUDE';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE users ADD last_known_latitude NUMBER(10, 6) DEFAULT 14.5995';
    DBMS_OUTPUT.PUT_LINE('Added users.last_known_latitude');
  END IF;

  SELECT COUNT(*) INTO v_count FROM user_tab_cols WHERE table_name = 'USERS' AND column_name = 'LAST_KNOWN_LONGITUDE';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE users ADD last_known_longitude NUMBER(10, 6) DEFAULT 120.9842';
    DBMS_OUTPUT.PUT_LINE('Added users.last_known_longitude');
  END IF;

  SELECT COUNT(*) INTO v_count FROM user_tab_cols WHERE table_name = 'USERS' AND column_name = 'LAST_KNOWN_LOCATION_NAME';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE users ADD last_known_location_name VARCHAR2(100) DEFAULT ''Manila, Philippines''';
    DBMS_OUTPUT.PUT_LINE('Added users.last_known_location_name');
  END IF;

  SELECT COUNT(*) INTO v_count FROM user_tab_cols WHERE table_name = 'USERS' AND column_name = 'LAST_KNOWN_IP';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE users ADD last_known_ip VARCHAR2(45) DEFAULT ''112.198.45.10''';
    DBMS_OUTPUT.PUT_LINE('Added users.last_known_ip');
  END IF;

  SELECT COUNT(*) INTO v_count FROM user_tab_cols WHERE table_name = 'USERS' AND column_name = 'LAST_GEO_UPDATED_AT';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE users ADD last_geo_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP';
    DBMS_OUTPUT.PUT_LINE('Added users.last_geo_updated_at');
  END IF;
  -- 2. ACCOUNTS TABLE: CURRENCY
  SELECT COUNT(*) INTO v_count FROM user_tab_cols WHERE table_name = 'ACCOUNTS' AND column_name = 'CURRENCY';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE accounts ADD currency VARCHAR2(3) DEFAULT ''PHP'' NOT NULL';
    DBMS_OUTPUT.PUT_LINE('Added accounts.currency');
  END IF;

  -- 3. TRANSACTIONS TABLE: CURRENCY & MEMO
  SELECT COUNT(*) INTO v_count FROM user_tab_cols WHERE table_name = 'TRANSACTIONS' AND column_name = 'CURRENCY';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE transactions ADD currency VARCHAR2(3) DEFAULT ''PHP'' NOT NULL';
    DBMS_OUTPUT.PUT_LINE('Added transactions.currency');
  END IF;

  SELECT COUNT(*) INTO v_count FROM user_tab_cols WHERE table_name = 'TRANSACTIONS' AND column_name = 'MEMO';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE transactions ADD memo VARCHAR2(255)';
    DBMS_OUTPUT.PUT_LINE('Added transactions.memo');
  END IF;

  -- 4. BALANCE_MASTER TABLE: SURROGATE BALANCE_ID PK
  SELECT COUNT(*) INTO v_count FROM user_tab_cols WHERE table_name = 'BALANCE_MASTER' AND column_name = 'BALANCE_ID';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE balance_master ADD balance_id VARCHAR2(64)';
    EXECUTE IMMEDIATE 'UPDATE balance_master SET balance_id = ''BM-'' || account_id WHERE balance_id IS NULL';
    EXECUTE IMMEDIATE 'ALTER TABLE balance_master MODIFY balance_id VARCHAR2(64) NOT NULL';
    DBMS_OUTPUT.PUT_LINE('Added balance_master.balance_id');
  END IF;

  -- Switch PK constraint to BALANCE_ID if still on ACCOUNT_ID
  BEGIN
    SELECT cols.column_name INTO v_pk_col
    FROM user_constraints cons, user_cons_columns cols
    WHERE cons.constraint_name = cols.constraint_name
      AND cons.table_name = 'BALANCE_MASTER'
      AND cons.constraint_type = 'P';

    IF v_pk_col != 'BALANCE_ID' THEN
      EXECUTE IMMEDIATE 'ALTER TABLE balance_master DROP PRIMARY KEY DROP INDEX';
      EXECUTE IMMEDIATE 'ALTER TABLE balance_master ADD CONSTRAINT pk_balance_master PRIMARY KEY (balance_id)';
      EXECUTE IMMEDIATE 'ALTER TABLE balance_master ADD CONSTRAINT uq_bm_account_id UNIQUE (account_id)';
      DBMS_OUTPUT.PUT_LINE('Transitioned balance_master PK to balance_id with unique account_id');
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      EXECUTE IMMEDIATE 'ALTER TABLE balance_master ADD CONSTRAINT pk_balance_master PRIMARY KEY (balance_id)';
      EXECUTE IMMEDIATE 'ALTER TABLE balance_master ADD CONSTRAINT uq_bm_account_id UNIQUE (account_id)';
  END;
END;
/
COMMIT;
EXIT;
