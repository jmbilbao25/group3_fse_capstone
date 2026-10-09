-- Add geo-location and tracking columns to users table
SET SERVEROUTPUT ON;

DECLARE
  v_count NUMBER;
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
END;
/
COMMIT;
EXIT;
