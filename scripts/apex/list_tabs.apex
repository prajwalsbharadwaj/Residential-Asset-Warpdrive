for (Schema.DescribeTabSetResult ts : Schema.describeTabs()) {
    System.debug('APP: ' + ts.getLabel());
    for (Schema.DescribeTabResult tab : ts.getTabs()) {
        System.debug('  TAB: label=' + tab.getLabel() + ' sobject=' + tab.getSobjectName() + ' isCustom=' + tab.isCustom());
    }
}
