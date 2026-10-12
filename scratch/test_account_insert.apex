Account cp = new Account(
    RecordTypeId = '012aj00000BTPJFAA5',
    LastName = 'Deccan Landmark Partners',
    FirstName = 'Hyderabad',
    Phone = '+91 40 6622 4400'
);
insert cp;
System.debug('Successfully inserted CP: ' + cp.Id);
