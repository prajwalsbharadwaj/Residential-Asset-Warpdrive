Schema.DescribeFieldResult dfr = PermissionSetTabSetting.Visibility.getDescribe();
for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
    System.debug('Value: ' + pe.getValue() + ' Label: ' + pe.getLabel());
}
