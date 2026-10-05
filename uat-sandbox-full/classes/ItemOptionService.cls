/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ItemOptionService
 * Author          : <YourName>
 * Created Date    : Apr 28, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Apr 28, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Apr 28, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class ItemOptionService {
    
    // Defines structure of an item name-image pair
    public class ItemDetail {
        public String itemName;
        public String itemImageUrl;
        public String itemMimeType;
        public ItemDetail(String itemName, String itemImageUrl, String itemMimeType) {
            this.itemName = itemName;
            this.itemImageUrl = itemImageUrl;
            this.itemMimeType = itemMimeType;
        }
    }
    
    // Represents an object that holds a list of item name-image pairs
    public class ItemOptionWrapper {
        @InvocableVariable(label='Item Options' required=true)
        public List<ItemDetail> itemDetails;
        public ItemOptionWrapper() {
            this.itemDetails = new List<ItemDetail>();
        }
    }
    
    // Reprents input for getItemOptionsByCategory
    public class ItemOptionInput {
        @InvocableVariable(label='Category Name' required=true)
        public String categoryName;
    }
    
    @InvocableMethod(label='Get Item Options by Category' description='Returns a list of item options based on the category name')
    public static List<ItemOptionWrapper> getItemOptionsByCategory(List<ItemOptionInput> categoryNames) {
        System.debug('categoryNames: ' + categoryNames);
        
        // Get the category name from the input list
        String category = categoryNames[0].categoryName.toLowerCase();
        System.debug('Processing category: ' + category);
        
        ItemOptionWrapper selectedItemWrapper = new ItemOptionWrapper();
        /*if(category.contains('2 bhk') ) {
            selectedItemWrapper.itemDetails.add(new ItemDetail('2 bhk(708) Tower 5','https://www.kenyt.com/api/image/download?apikey=kenyttest&mode=pad&notrim=1&w=325&h=250&path=https%3A%2F%2Fwww.kenyt.ai%2Fbotapp%2Fapi%2Fbotsetup%2Fgetimage%3Fbotclientid%3D111918113%26imagetype%3D2bhk-t5-708sft.jpg', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('2 bhk(737) Tower 8','https://www.kenyt.com/api/image/download?apikey=kenyttest&mode=pad&notrim=1&w=325&h=250&path=https%3A%2F%2Fwww.kenyt.ai%2Fbotapp%2Fapi%2Fbotsetup%2Fgetimage%3Fbotclientid%3D111918113%26imagetype%3D2bhk-t8-737sft.jpg', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Youtube','https://www.youtube.com/watch?v=5yl-DC5wu1U', 'video/mp4'));
            
        }if(category.contains('3 bhk') ) {
            selectedItemWrapper.itemDetails.add(new ItemDetail('3 bhk(1148) Tower 8','https://www.kenyt.com/api/image/download?apikey=kenyttest&mode=pad&notrim=1&w=325&h=250&path=https%3A%2F%2Fwww.kenyt.ai%2Fbotapp%2Fapi%2Fbotsetup%2Fgetimage%3Fbotclientid%3D111918113%26imagetype%3D3bhk-t8-1148sft.jpg', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('3 bhk(852) Tower 5','https://www.kenyt.com/api/image/download?apikey=kenyttest&mode=pad&notrim=1&w=325&h=250&path=https%3A%2F%2Fwww.kenyt.ai%2Fbotapp%2Fapi%2Fbotsetup%2Fgetimage%3Fbotclientid%3D111918113%26imagetype%3D3bhk-t5-852sft.jpg', 'image/jpeg'));
        //    selectedItemWrapper.itemDetails.add(new ItemDetail('Youtube','https://www.youtube.com/watch?v=5yl-DC5wu1U', 'video/mp4'));
            
        }
        if(category.contains('duplex') ) {
            selectedItemWrapper.itemDetails.add(new ItemDetail('Duplex(2078) Tower 5','https://www.kenyt.com/api/image/download?apikey=kenyttest&mode=pad&notrim=1&w=325&h=250&path=https%3A%2F%2Fwww.kenyt.ai%2Fbotapp%2Fapi%2Fbotsetup%2Fgetimage%3Fbotclientid%3D111918113%26imagetype%3Dduplex-t5-2078sft.jpg', 'image/jpeg'));
        //    selectedItemWrapper.itemDetails.add(new ItemDetail('3 bhk(852) Tower 5','https://www.kenyt.com/api/image/download?apikey=kenyttest&mode=pad&notrim=1&w=325&h=250&path=https%3A%2F%2Fwww.kenyt.ai%2Fbotapp%2Fapi%2Fbotsetup%2Fgetimage%3Fbotclientid%3D111918113%26imagetype%3D3bhk-t5-852sft.jpg', 'image/jpeg'));
        //    selectedItemWrapper.itemDetails.add(new ItemDetail('Youtube','https://www.youtube.com/watch?v=5yl-DC5wu1U', 'video/mp4'));
            
        }if(category.contains('penthouse') ) {
            selectedItemWrapper.itemDetails.add(new ItemDetail('Penthouse(2967) Tower 8','https://www.kenyt.com/api/image/download?apikey=kenyttest&mode=pad&notrim=1&w=325&h=250&path=https%3A%2F%2Fwww.kenyt.ai%2Fbotapp%2Fapi%2Fbotsetup%2Fgetimage%3Fbotclientid%3D111918113%26imagetype%3Dpenthouse-t8-3245sft.jpg', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Penthouse(3245) Tower 5','https://www.kenyt.com/api/image/download?apikey=kenyttest&mode=pad&notrim=1&w=325&h=250&path=https%3A%2F%2Fwww.kenyt.ai%2Fbotapp%2Fapi%2Fbotsetup%2Fgetimage%3Fbotclientid%3D111918113%26imagetype%3Dpenthouse-t5-2967sft.jpg', 'image/jpeg'));
        //    selectedItemWrapper.itemDetails.add(new ItemDetail('Youtube','https://www.youtube.com/watch?v=5yl-DC5wu1U', 'video/mp4'));
            
        }
        if(category.contains('floor')  ){
            system.debug('category'+category);           
         //   selectedItemWrapper.itemDetails.add(new ItemDetail('2 bhk(708) Tower 8','https://www.kenyt.com/api/image/download?apikey=kenyttest&mode=pad&notrim=1&w=325&h=250&path=https%3A%2F%2Fwww.kenyt.ai%2Fbotapp%2Fapi%2Fbotsetup%2Fgetimage%3Fbotclientid%3D111918113%26imagetype%3D2bhk-t5-708sft.jpg', 'image/jpeg'));
         //   selectedItemWrapper.itemDetails.add(new ItemDetail('2 bhk(737) Tower 5','https://www.kenyt.com/api/image/download?apikey=kenyttest&mode=pad&notrim=1&w=325&h=250&path=https%3A%2F%2Fwww.kenyt.ai%2Fbotapp%2Fapi%2Fbotsetup%2Fgetimage%3Fbotclientid%3D111918113%26imagetype%3D2bhk-t8-737sft.jpg', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Floor & Unit Plan', 'https://d1nfgpflnbq58s.cloudfront.net/projects/March2025/ariana_floor_&_unit_plan_booklet_A4_26.02.25_digital.pdf', 'application/pdf'));     
        }
        else if(category.contains('gallery')) {
            selectedItemWrapper.itemDetails.add(new ItemDetail('Gallery 1', 'https://media.tatahousing.com/galleries/July2023/8f31bb14db722b1679d2.webp', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Gallery 2', 'https://media.tatahousing.com/galleries/July2023/c7fb51a4769c9c69b667.webp', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Gallery 3', 'https://media.tatahousing.com/galleries/July2023/3ffc380f95e79a17f6f4.webp', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Gallery 4', 'https://media.tatahousing.com/galleries/July2023/9a1f2650bab1bbaac55b.webp', 'image/jpeg'));
        }*/if(category.contains('amenities')){
            selectedItemWrapper.itemDetails.add(new ItemDetail('Sports Arena', 'https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId=068aj00000Ixg8v&operationContext=CHATTER&contentId=05Taj00000Pb9cD', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Amphitheatre','https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId=068aj00000IxgDl&operationContext=CHATTER&contentId=05Taj00000Pb9h3', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Lounge / Bamquet Hall', 'https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId=068aj00000IxgAX&operationContext=CHATTER&contentId=05Taj00000Pb9dp', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Sky Cabana','https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId=068aj00000IxgFN&operationContext=CHATTER&contentId=05Taj00000Pb9if', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Reflexology Pathway', 'https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId=068aj00000IxgC9&operationContext=CHATTER&contentId=05Taj00000Pb9fR', 'image/jpeg'));
            // //------------------------------New Added---------------------------------------------------------------------------------------------------------------
            // selectedItemWrapper.itemDetails.add(new ItemDetail('WD Socity1', 'https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Jpg&versionId=068aj00000IyC0j&operationContext=CHATTER&contentId=05Taj00000PcMYz', 'image/jpeg'));
            // selectedItemWrapper.itemDetails.add(new ItemDetail('WD Socity2', 'https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Jpg&versionId=068aj00000IyBxV&operationContext=CHATTER&contentId=05Taj00000PcMVl', 'image/jpeg'));
            // selectedItemWrapper.itemDetails.add(new ItemDetail('WD Socity3', 'https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Jpg&versionId=068aj00000IyBnp&operationContext=CHATTER&contentId=05Taj00000PcMKT', 'image/jpeg'));
            // selectedItemWrapper.itemDetails.add(new ItemDetail('TowerImg1', 'https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Jpg&versionId=068aj00000IyBpR&operationContext=CHATTER&contentId=05Taj00000PcMM5', 'image/jpeg'));
            // selectedItemWrapper.itemDetails.add(new ItemDetail('TowerImg2', 'https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Jpg&versionId=068aj00000IyBuH&operationContext=CHATTER&contentId=05Taj00000PcMSX', 'image/jpeg'));
            // selectedItemWrapper.itemDetails.add(new ItemDetail('TowerImg3', 'https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Jpg&versionId=068aj00000IyBz7&operationContext=CHATTER&contentId=05Taj00000PcMXN', 'image/jpeg'));
            // //------------------------------New Added--------------------------------------------------------------------------------------------
      //      selectedItemWrapper.itemDetails.add(new ItemDetail('Board games', 'https://tatarealty--agentforce.sandbox.my.salesforce.com/sfc/p/Ip0000000X1b/a/Ip000000L3GY/LGR.Uyd_RScFJNj3CMv4Q7N9gHKVr4QdUDcapGuGZtQ', 'application/pdf'));
      //      selectedItemWrapper.itemDetails.add(new ItemDetail('Tennis Court', 'https://media.tatahousing.com/amenities/November2024/d8afa2b2656835afdd08.webp', 'image/jpeg'));
      //      selectedItemWrapper.itemDetails.add(new ItemDetail('Basketball court', 'https://media.tatahousing.com/amenities/November2024/96bf1584871967fc027b.webp', 'image/jpeg'));
      //      selectedItemWrapper.itemDetails.add(new ItemDetail('Kids Play Area', 'https://media.tatahousing.com/amenities/November2024/c4d0af31f62da97cf2c5.webp', 'image/jpeg'));
       //     selectedItemWrapper.itemDetails.add(new ItemDetail('Kids Play Area', 'https://example.com/images/gym.jpg','https://example.com/videos/gym-tour.mp4'));
            
        } /*else if (category.contains('brochure') ) {
            system.debug('category'+category);
            selectedItemWrapper.itemDetails.add(new ItemDetail('Brochure', 'https://wa1730889235183.my.salesforce.com/sfc/p/Kd000005aTu6/a/Kd0000024sm2/N5MqSBiFNnHtlB3UPz3lOA_PDjblud.BWp37rWqOHAQ', 'application/pdf'));
        }*/
        else if (category.contains('layout') ) {
            system.debug('category'+category);
            selectedItemWrapper.itemDetails.add(new ItemDetail('Master Plan', 'https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId=068aj00000IxgGz&operationContext=CHATTER&contentId=05Taj00000Pb9kH', 'image/jpeg'));
        }/*else if(category.contains('floor')){
            system.debug('category'+category);           
            selectedItemWrapper.itemDetails.add(new ItemDetail('Floor & Unit Plan', 'https://d1nfgpflnbq58s.cloudfront.net/projects/March2025/ariana_floor_&_unit_plan_booklet_A4_26.02.25_digital.pdf', 'application/pdf'));            
        }*/else if(category.contains('location')){
            system.debug('category'+category);           
            selectedItemWrapper.itemDetails.add(new ItemDetail('Location Map','https://wa1775550540999.file.force.com/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId=068aj00000IxgIb&operationContext=CHATTER&contentId=05Taj00000Pb9lt', 'image/jpeg'));
            selectedItemWrapper.itemDetails.add(new ItemDetail('Google Map','https://www.google.com/maps/dir//Golf+Avenue,+next+to+KGA+Road,+Indiranagar,+Kodihal[…]6!5m1!1e2?entry=ttu&g_ep=EgoyMDI1MDgwNi4wIKXMDSoASAFQAw%3D%3D', 'application/pdf'));
        }
        System.debug('Returning : ' + selectedItemWrapper);
        return new List<ItemOptionWrapper>{ selectedItemWrapper };
            }
}