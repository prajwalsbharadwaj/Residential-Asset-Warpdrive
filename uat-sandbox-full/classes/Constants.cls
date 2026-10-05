public class Constants {
	
    public static Id PROFILE_ID_SYSTEM_ADMINISTRATOR {
        get {
            if(PROFILE_ID_SYSTEM_ADMINISTRATOR == null){
                PROFILE_ID_SYSTEM_ADMINISTRATOR = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id;
            }
            return PROFILE_ID_SYSTEM_ADMINISTRATOR;
        } set;
    }
}