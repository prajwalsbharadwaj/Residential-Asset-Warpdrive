@isTest
public class SAPChannelPartnerMock implements HttpCalloutMock {

    protected Integer statusCode;
    protected String status;
    protected String body;

    // Constructor for setting response details
    public SAPChannelPartnerMock(Integer statusCode, String status, String body) {
        this.statusCode = statusCode;
        this.status = status;
        this.body = body;
    }

    // This method is called by the test framework to get the mock response.
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(this.body);
        res.setStatusCode(this.statusCode);
        res.setStatus(this.status);
        return res;
    }
}