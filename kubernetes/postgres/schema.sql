CREATE SCHEMA catalog;
CREATE TABLE catalog.products (
  id text PRIMARY KEY,
  name text NOT NULL,
  description text NOT NULL,
  picture text NOT NULL,
  price_currency_code text NOT NULL,
  price_units bigint NOT NULL,
  price_nanos integer NOT NULL,
  categories text NOT NULL
);
INSERT INTO catalog.products VALUES
  ('OLJCESPC7Z', 'Learning Telescope', 'Synthetic telescope for this local demo.', 'NationalParkFoundationExplorascope.jpg', 'USD', 101, 960000000, 'telescopes'),
  ('66VCHSJNUP', 'Explorer Telescope', 'Synthetic catalog item for checkout exercises.', 'StarsenseExplorer.jpg', 'USD', 349, 950000000, 'telescopes'),
  ('L9ECAV7KIM', 'Lens Cleaning Kit', 'Synthetic accessory for the learning store.', 'LensCleaningKit.jpg', 'USD', 21, 950000000, 'accessories'),
  ('LS4PSXUNUM', 'Red Flashlight', 'Synthetic flashlight for tracing examples.', 'RedFlashlight.jpg', 'USD', 57, 80000000, 'accessories,flashlights');
INSERT INTO catalog.products VALUES
  ('1YMWWN1N4O', 'Travel Telescope', 'Synthetic travel item.', 'EclipsmartTravelRefractorTelescope.jpg', 'USD', 129, 950000000, 'telescopes,travel'),
  ('2ZYFJ3GM2N', 'Learning Binoculars', 'Synthetic binoculars.', 'RoofBinoculars.jpg', 'USD', 209, 950000000, 'binoculars'),
  ('0PUK6V6EV0', 'Color Imager', 'Synthetic imaging accessory.', 'SolarSystemColorImager.jpg', 'USD', 175, 0, 'accessories,telescopes'),
  ('9SIQT8TOJO', 'Optical Tube', 'Synthetic optical assembly.', 'OpticalTubeAssembly.jpg', 'USD', 3599, 0, 'accessories,telescopes,assembly'),
  ('6E92ZMYYFZ', 'Solar Filter', 'Synthetic filter.', 'SolarFilter.jpg', 'USD', 69, 950000000, 'accessories,telescopes'),
  ('HQTGWGPNH4', 'Comet Book', 'Synthetic book.', 'TheCometBook.jpg', 'USD', 0, 990000000, 'books');
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA catalog TO catalog_reader;
GRANT SELECT, UPDATE ON catalog.products TO catalog_reader;
