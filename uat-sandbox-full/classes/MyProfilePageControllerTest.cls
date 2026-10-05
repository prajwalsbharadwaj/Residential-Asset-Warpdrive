/**
 * An apex class that updates details of a portal user.
   Guest users are never able to access this page.
 */
@IsTest public with sharing class MyProfilePageControllerTest {

    @IsTest(SeeAllData=true) static void testSave() {
        // Modify the test to query for a portal user that exists in your org
        List<User> existingPortalUsers = [SELECT id, profileId, userRoleId FROM User WHERE UserRoleId <> null AND UserType='CustomerSuccess'];

        if (existingPortalUsers.isEmpty()) {
            User currentUser = [select id, title, firstname, lastname, email, phone, mobilephone, fax, street, city, state, postalcode, country
                                FROM User WHERE id =: UserInfo.getUserId()];
            MyProfilePageController controller = new MyProfilePageController();
            System.assertEquals(currentUser.Id, controller.getUser().Id, 'Did not successfully load the current user');
            System.Assert.isTrue(controller.getIsEdit() == false, 'isEdit should default to false');
            controller.edit();
            System.Assert.isTrue(controller.getIsEdit() == true, 'isEdit should be true after toggle.');
            controller.cancel();
            System.Assert.isTrue(controller.getIsEdit() == false, 'isEdit should be false after toggle.');
            
            System.Assert.isTrue(Page.ChangePassword.getUrl().equals(controller.changePassword().getUrl()), 'Change password URL should match.');
            
            String randFax = Math.rint(Math.random() * 1000) + '5551234';
            controller.getUser().Fax = randFax;
            controller.save();
            System.Assert.isTrue(controller.getIsEdit() == false, 'isEdit should be false initially.');
            
            currentUser = [Select id, fax from User where id =: currentUser.Id];
            System.Assert.isTrue(currentUser.fax == randFax, 'Fax should be updated.');
        } else {
            User existingPortalUser = existingPortalUsers[0];
            String randFax = Math.rint(Math.random() * 1000) + '5551234';

            System.runAs(existingPortalUser) {
                MyProfilePageController controller = new MyProfilePageController();
                System.assertEquals(existingPortalUser.Id, controller.getUser().Id, 'Did not successfully load the current user');
                System.Assert.isTrue(controller.getIsEdit() == false, 'isEdit should default to false');
                controller.edit();
                System.Assert.isTrue(controller.getIsEdit() == true, 'Expected true after set.');

                controller.cancel();
                System.Assert.isTrue(controller.getIsEdit() == false, 'Expected false after set.');

                controller.getUser().Fax = randFax;
                controller.save();
                System.Assert.isTrue(controller.getIsEdit() == false, 'Expected false.');
            }

            // verify that the user was updated
            existingPortalUser = [Select id, fax from User where id =: existingPortalUser.Id];
            System.Assert.isTrue(existingPortalUser.fax == randFax, 'Fax should be updated for portal user.');
        }
    }
}