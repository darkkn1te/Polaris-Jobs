if exists(
SELECT
	p.PatronID AS [PatronID],
	p.Barcode AS [Barcode],
	pc.Description AS [Patron Code],
	@recipients = pu.Name AS [Creator],
	addr.StreetOne AS [Street One],
	addr.StreetTwo AS [Street Two],
	pos.City AS [City],
	pos.State AS [State],
	pos.County AS [County],
	pos.PostalCode AS [ZIP Code],
	o.Name AS [Registration Branch],
	pr.RegistrationDate AS [Registration Date],
	pr.ExpirationDate AS [Expiration Date]

FROM
	Polaris.Polaris.Patrons p WITH (NOLOCK)

INNER JOIN -- Need to join to get patron addresses tied to the Addresses table
	Polaris.Polaris.PatronAddresses padd WITH (NOLOCK)
	ON (p.PatronID = padd.PatronID)
INNER JOIN -- Join to get the actual address information
	Polaris.Polaris.Addresses addr WITH (NOLOCK)
	ON (addr.AddressID = padd.addressID)
INNER JOIN -- City, State, County, and ZIP
	Polaris.Polaris.PostalCodes pos WITH (NOLOCK)
	ON (pos.PostalCodeID = addr.PostalCodeID)
INNER JOIN -- Pulls Patron Code description
	Polaris.Polaris.PatronCodes pc WITH (NOLOCK)
	ON (p.PatronCodeID = pc.PatronCodeID)
INNER JOIN -- Gets the username of whoever created the patron record
	Polaris.Polaris.PolarisUsers pu WITH (NOLOCK)
	ON (p.CreatorID = pu.PolarisUserID)
INNER JOIN -- Gets the organization name for Registration Branch
	Polaris.Polaris.Organizations o WITH (NOLOCK)
	ON (o.OrganizationID = p.OrganizationID)
INNER JOIN -- Gets the registration and expiration date
	Polaris.Polaris.PatronRegistration pr WITH (NOLOCK)
	ON (pr.PatronID = p.PatronID)

WHERE
	addr.AddressID IN (
	SELECT AddressID FROM Polaris.Polaris.Addresses WITH (NOLOCK)
	WHERE StreetOne NOT LIKE '%[0-9]%') -- Weeds out anything with numbers in the Street One address
AND
	p.PatronCodeID != 5 -- eCard PatronCodeID
AND
	pr.registrationDate < DATEADD(day, -7, GETDATE());
)

begin
exec msdb.dbo.sp_send_dbmail
	@profile_name = 'Prod Mail',
	@recipients,
	@subject = 'Errors in Club 81 Student Records',
	@query = 'select p.barcode, pr.RegistrationDate from polaris.polaris.patrons p with (nolock)
inner join polaris.polaris.patronregistration pr with (nolock)
on p.patronid = pr.patronid
inner join polaris.polaris.patronaddresses padd with (nolock)
on p.patronid = padd.patronid
inner join polaris.polaris.addresses addr with (nolock)
on addr.AddressID = padd.AddressID
inner join polaris.polaris.polarisusers pu with (nolock)
on p.creatorID = pu.PolarisUserID
where pr.registrationDate < DATEADD(day, -7, GETDATE())
and addr.AddressID in (select AddressID from Polaris.polaris.Addresses with (nolock) where StreetOne NOT LIKE "%[0-9]%")
and p.PatronCodeID != 5;'
	
end

