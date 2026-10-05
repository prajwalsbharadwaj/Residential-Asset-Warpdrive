global class ExternalLeadWrapper {
        public String country_code;
        public String email;
        public String name;
        public String phone;
        public String project_name;
        public String rating;
        public String city;
        public ExtraDetails extra_details;
    	public String lead_status;
    	public String action;
        // Optional fields
        
        public String source;
        public String sub_source;
        //public String agent_email;
        //public String agent_name;
        //public String developer;

        public class ExtraDetails {
            public String gender;
            public String address;
            public String industry;
            public String company_name;
        }
    }