-- function equivalent to Postgres's ST_ROTATE for MySQL/MariaDB
-- only works on polygons, rotates around the bounding box's centre point
-- requires a third parameter, which if true will transpose the points to be aligned with a rotated bounding box
CREATE FUNCTION `ST_ROTATEPOLYGON`(`POLY` POLYGON, `DEG` DOUBLE, `TRANSP` BOOLEAN) RETURNS polygon
    NO SQL
    DETERMINISTIC
BEGIN
DECLARE json TEXT;
DECLARE th DOUBLE;
DECLARE l DOUBLE;
DECLARE t DOUBLE;
DECLARE w DOUBLE;
DECLARE h DOUBLE;
DECLARE cx DOUBLE;
DECLARE cy DOUBLE;
DECLARE x DOUBLE;
DECLARE y DOUBLE;
DECLARE rx DOUBLE;
DECLARE ry DOUBLE;
DECLARE rw DOUBLE;
DECLARE rh DOUBLE;
DECLARE offx DOUBLE;
DECLARE offy DOUBLE;
DECLARE n INT;
DECLARE pt TEXT;
DECLARE outjson TEXT;
DECLARE err TEXT;
-- get as json with bounding box
SET json = ST_AsGeoJSON(POLY,2,1);
-- convert degrees to radians
SET th = (DEG * PI()) / 180;
-- determine rotate point by using centre point of bounding box
SET l = JSON_EXTRACT(json,'$.bbox[0]');
SET t = JSON_EXTRACT(json,'$.bbox[1]');
SET w = JSON_EXTRACT(json,'$.bbox[2]') - l;
SET h = JSON_EXTRACT(json,'$.bbox[3]') - t;
-- rotated width and height
SET rw = h * ABS(SIN(th)) + w * ABS(COS(th));
SET rh = h * ABS(COS(th)) + w * ABS(SIN(th));
-- calculate offset for transposition if selected
SET offx = IF(TRANSP, l - (rw - w)/2, 0);
SET offy = IF(TRANSP, t - (rh - h)/2, 0);
-- calculate centre point of original bounding box
SET cx = l + w/2;
SET cy = t + h/2;
-- iterator and json builder string
SET n = 0;
SET outjson = '';
-- go through coordinates
WHILE JSON_EXTRACT(json,CONCAT('$.coordinates[0][',n,']')) IS NOT NULL DO
  SET pt = JSON_EXTRACT(json,CONCAT('$.coordinates[0][',n,']'));
  SET x = JSON_VALUE(pt,'$[0]');
  SET y = JSON_VALUE(pt,'$[1]');
  -- rotate points around centre point
  SET rx = COS(th) * (x - cx) - SIN(th) * (y - cy) + cx - offx;
  SET ry = SIN(th) * (x - cx) + COS(th) * (y - cy) + cy - offy;
  -- manually build json array string
  SET outjson = CONCAT(outjson,'[',rx,',',ry,'],');
  -- iterate
  SET n = n + 1;
END WHILE;
-- build json string
SET outjson = CONCAT('{"type":"Polygon","coordinates":[[',REGEXP_REPLACE(outjson,',$',''),']]}');
-- return parsed json string
RETURN ST_GeomFromGeoJSON(outjson);
END
