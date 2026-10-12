List<WdGlassRecordController.ActionItem> items = WdGlassRecordController.getActions('Account');
for (WdGlassRecordController.ActionItem a : items) {
    System.debug('ACTION: ' + a.apiName + ' -> ' + a.label);
}
