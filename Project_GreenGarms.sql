CREATE DATABASE GreenGarms;
USE GreenGarms;

/*GreenGarms is a clothing company looking to produce a new item of clothing.
We are not into greenwashing, and we will choose our new product based 
on the lowest carbon footprint.
This database is to help us work out what our new garm will be.
It doesn’t matter what we look like, it’s the carbon emissions that count. */

/*This table showcases our clothing options (G_id is our primary key representing each individual garm) */

CREATE TABLE GarmMetrics
(G_id INT NOT NULL PRIMARY KEY,
Man_id INT NOT NULL,
Primary_Material VARCHAR(50) NOT NULL,
Clothing_Weight INT NOT NULL);

INSERT INTO GarmMetrics
(G_id, Man_id, Primary_Material, Clothing_Weight)
VALUES
(1, 2, 'Polyester', 130), 
(2, 3, 'Polyester', 349),
(3, 1, 'Cotton', 543),
(4, 4, 'Linen', 553);



/*This table helps us to estimate the emissions involved in transforming the raw materials into garms */

CREATE TABLE Raw_Material
(Material VARCHAR(50) NOT NULL PRIMARY KEY,
Emissions DECIMAL(6,3));

INSERT INTO Raw_Material
(Material, Emissions)
VALUES
('Polyester', 261.720),
('Cotton', 289.865),
('Linen', 201.450); 


/*These three tables will help us work out the emissions caused when we transport the items*/ 

CREATE TABLE Manufacturer
(Man_id INT NOT NULL,
Company_name VARCHAR(50) NOT NULL,
Location VARCHAR(50) NOT NULL,
Transport_type VARCHAR(50) NOT NULL,
CONSTRAINT pk_Man_id PRIMARY KEY (Man_id)
);

INSERT INTO Manufacturer
(Man_id, Company_name, Location, Transport_type)
VALUES
(1, 'IndiaGarments', 'India', 'Ship'),
(2, 'ChinaCharms', 'China', 'Ship'),
(3, 'TurkishApparel', 'Turkey', 'Train'),
(4, 'ThaiThreads', 'Thailand', 'Aeroplane');

CREATE TABLE Distance_from_UK
(Location VARCHAR(50) NOT NULL,
Distance INT NOT NULL,
CONSTRAINT pk_Location PRIMARY KEY (Location));

INSERT INTO Distance_from_UK
(Location, Distance)
VALUES
('India', 6704),
('China', 7775),
('Turkey', 4388),
('Thailand', 9435);

CREATE TABLE Transport
(Transport_Type VARCHAR(50) NOT NULL PRIMARY KEY,
Emissions DECIMAL(9,2));

INSERT INTO Transport
(Transport_Type, Emissions)
VALUES
('Aeroplane', 435.35), 
('Ship', 007.95),
('Train', 026.50);


/*This table tells us how each manufacturer is able to supply of garms. Our accountant likes this table - profit requires quantity :D. 
We don’t have total quantities yet tho! */ 

CREATE TABLE Supply
(Man_id INT NOT NULL,
Expected_quantity INT NOT NULL,
Expected_Profit INT NOT NULL);

INSERT INTO Supply
(Man_id, Expected_quantity, Expected_Profit)
VALUES
(1, 157, 3140),
(2, 260, 1300);


/* We need foreign keys to relate our tables */ 

ALTER TABLE Manufacturer
ADD CONSTRAINT 
fk_Location
FOREIGN KEY
(Location)
REFERENCES 
Distance_from_UK 
(Location);

ALTER TABLE Manufacturer
ADD CONSTRAINT 
fk_Transport_type
FOREIGN KEY
(Transport_type)
REFERENCES 
Transport
(Transport_Type);

ALTER TABLE GarmMetrics
ADD CONSTRAINT
fk_Primary_Material 
FOREIGN KEY
(Primary_Material)
References 
Raw_Material
(Material);


*/ stored function
Oopsies we put clothing weight in grams, we must convert to kg to calculate total transport emissions!! */ 

DELIMITER //
CREATE FUNCTION g_to_kg (
Clothing_Weight INT
)
RETURNS DECIMAL(4,3)
DETERMINISTIC
BEGIN
RETURN (Clothing_Weight/1000);
END//
DELIMITER ; 

/* we call the code to check it’s worked now & yay it has! */

select G_id, g_to_kg(Clothing_Weight)
FROM GarmMetrics;



/* join to create manufacturer distance emissions table*/ 
CREATE VIEW TE AS
SELECT Manufacturer.Man_id, Transport.Emissions * Distance_from_UK.Distance as TotalTE
FROM Manufacturer 
 JOIN Distance_from_UK ON Manufacturer.Location=Distance_from_UK.Location
 JOIN Transport ON Manufacturer.Transport_type= Transport.Transport_Type;


/*join that calculates material emissions for each garment*/

CREATE VIEW ME AS
SELECT GarmMetrics.G_id, Raw_Material.Emissions * GarmMetrics.Clothing_Weight as TotalME
FROM GarmMetrics
 JOIN Raw_Material ON GarmMetrics.Primary_Material=Raw_Material.Material;


/*creating a table that combines both of these tables */
CREATE VIEW garment_emissions AS
SELECT GarmMetrics.G_id, TE.TotalTE*GarmMetrics.Clothing_Weight as TotalTE, ME.TotalME
FROM GarmMetrics
	JOIN TE ON GarmMetrics.Man_id=TE.Man_id
    JOIN ME ON GarmMetrics.G_id =ME.G_id;


/* using a query so that we can see the largest garment emitters */
SELECT G_id, (TotalTE + TotalME) as total_emissions
FROM garment_emissions
ORDER BY total_emissions DESC;


/*We’ve decided to investigate garments with less than average material emissions/ transport emissions to see if this would give us the same garment choice.  */ 

/*example sub query - found the garments with less than the average total material emissions */
SELECT G_id, TotalME 
FROM garment_emissions
WHERE TotalME < (
	SELECT AVG(TotalME)
    FROM garment_emissions
);

/*finding garments with less selthan the average transport emissions */ 
SELECT G_id, TotalTE 
FROM garment_emissions
WHERE TotalTE < (
	SELECT AVG(TotalTE)
    FROM garment_emissions
);

/*we’ve realised it would be helpful to be able to do this as a procedure, finding the best garment that has lowest total emissions whilst being below average transport and material emissions */ 
DELIMITER //
CREATE PROCEDURE best_garment (
total_emissions INT
)
BEGIN
SELECT G_id, (TotalTE + TotalME) as total_emissions
FROM garment_emissions
WHERE TotalME < ( SELECT AVG(TotalME) FROM garment_emissions)
        AND TotalTE < (
				SELECT AVG(TotalTE)
				FROM garment_emissions ); 
END//
DELIMITER ; 

/* we call the code to check it’s worked */ 
CALL best_garment (4);

/* This trigger doesn't work. Liz and Charlotte's tips: set new.expectedprofit etc. 

our accountant wants us to calculate how much profit we'd make using each manufacturer
when they let us know how much they can produce
So we’re creating a trigger to do that 

create trigger calculate 
before INSERT 
ON Supply
FOR EACH ROW
SET Supply.Expected_Profit = Expected_quantity * 50;

/* so when we update the table…

INSERT INTO Supply
(Man_id, Expected_quantity)
VALUES
(3, 820),
(4, 690);

*/
