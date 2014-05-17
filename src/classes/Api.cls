/*
 * Thanks Jeremy for example_att_info inspiration:
 * http://stackoverflow.com/a/4463751/1606872
 */
global class Api {
    global class CallOptions_element {
        global String client;
        private String[] client_type_info = new String[]{'client','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'client'};
    }
    global class AllowFieldTruncationHeader_element {
        global Boolean allowFieldTruncation;
        private String[] allowFieldTruncation_type_info = new String[]{'allowFieldTruncation','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'allowFieldTruncation'};
    } 
    global class DisableFeedTrackingHeader_element {
        global Boolean disableFeedTracking;
        private String[] disableFeedTracking_type_info = new String[]{'disableFeedTracking','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'disableFeedTracking'};
    }
    global class DebuggingHeader_element {
        global Api.LogInfo[] categories;
        global String debugLevel;
        private String[] categories_type_info = new String[]{'categories','urn:tooling.soap.sforce.com',null,'0','-1','false'};
        private String[] debugLevel_type_info = new String[]{'debugLevel','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'categories','debugLevel'};
    }
    global class LogInfo {
        global String category;
        global String level;
        private String[] category_type_info = new String[]{'category','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] level_type_info = new String[]{'level','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'category','level'};
    }
    global class executeAnonymous_element {
        global String String_x;
        private String[] String_x_type_info = new String[]{'String','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'String_x'};
    }
    global class queryResponse_element {
        global Api.QueryResult result;
        private String[] result_type_info = new String[]{'result','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'result'};
    }
    global class QueryResult {
        global Boolean done;
        global String entityTypeName;
        global String nextRecordsUrl;
        global String queryLocator;
        global Api.sObject_x[] records;
        global Integer size;
        global Integer totalSize;
        private String[] done_type_info = new String[]{'done','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] entityTypeName_type_info = new String[]{'entityTypeName','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] nextRecordsUrl_type_info = new String[]{'nextRecordsUrl','urn:tooling.soap.sforce.com',null,'0','1','false'};
        private String[] queryLocator_type_info = new String[]{'queryLocator','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] records_type_info = new String[]{'records','urn:tooling.soap.sforce.com',null,'0','-1','false'};
        private String[] size_type_info = new String[]{'size','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] totalSize_type_info = new String[]{'totalSize','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'done','entityTypeName','nextRecordsUrl','queryLocator','records','size','totalSize'};
    }
    virtual global class sObject_x {
        global String[] fieldsToNull;
        global String Id;
        private String[] fieldsToNull_type_info = new String[]{'fieldsToNull','urn:tooling.soap.sforce.com',null,'0','-1','true'};
        private String[] Id_type_info = new String[]{'Id','urn:tooling.soap.sforce.com',null,'1','1','true'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'fieldsToNull','Id'};
    }
    global class SessionHeader_element {
        global String sessionId;
        private String[] sessionId_type_info = new String[]{'sessionId','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'sessionId'};
    }


    global class executeAnonymousResponse_element {
        global Api.ExecuteAnonymousResult result;
        private String[] result_type_info = new String[]{'result','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'result'};
    }


    global class query_element {
        global String queryString;
        private String[] queryString_type_info = new String[]{'queryString','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'queryString'};
    }
    global class ApexResult {
        global String apexError;
        global Api.ExecuteAnonymousResult apexExecutionResult;
        private String[] apexError_type_info = new String[]{'apexError','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apexExecutionResult_type_info = new String[]{'apexExecutionResult','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'apexError','apexExecutionResult'};
    }

    global class Error {
        global String[] fields;
        global String message;
        global String statusCode;
        private String[] fields_type_info = new String[]{'fields','urn:tooling.soap.sforce.com',null,'0','-1','false'};
        private String[] message_type_info = new String[]{'message','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] statusCode_type_info = new String[]{'statusCode','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'fields','message','statusCode'};
    }
    global class ExecuteAnonymousResult {
        global Integer column;
        global String compileProblem;
        global Boolean compiled;
        global String exceptionMessage;
        global String exceptionStackTrace;
        global Integer line;
        global Boolean success;
        private String[] column_type_info = new String[]{'column','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] compileProblem_type_info = new String[]{'compileProblem','urn:tooling.soap.sforce.com',null,'1','1','true'};
        private String[] compiled_type_info = new String[]{'compiled','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] exceptionMessage_type_info = new String[]{'exceptionMessage','urn:tooling.soap.sforce.com',null,'1','1','true'};
        private String[] exceptionStackTrace_type_info = new String[]{'exceptionStackTrace','urn:tooling.soap.sforce.com',null,'1','1','true'};
        private String[] line_type_info = new String[]{'line','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] success_type_info = new String[]{'success','urn:tooling.soap.sforce.com',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:tooling.soap.sforce.com','true','false'};
        private String[] field_order_type_info = new String[]{'column','compileProblem','compiled','exceptionMessage','exceptionStackTrace','line','success'};
    }

    global class Client {
        
        global Client() {
            this(UserInfo.getSessionId());
        }
        
        global Client(String sessionId) {
            this.SessionHeader = new Api.SessionHeader_element();
            this.SessionHeader.sessionId = sessionId;
        }
        
        global String endpoint_x = System.Url.getSalesforceBaseUrl().toExternalForm() + '/services/Soap/T/30.0';
        global Map<String,String> inputHttpHeaders_x;
        global Map<String,String> outputHttpHeaders_x;
        global String clientCertName_x;
        global String clientCert_x;
        global String clientCertPasswd_x;
        global Integer timeout_x;
        global Api.CallOptions_element CallOptions;
        global Api.DisableFeedTrackingHeader_element DisableFeedTrackingHeader;
        global Api.DebuggingHeader_element DebuggingHeader;
        global Api.AllowFieldTruncationHeader_element AllowFieldTruncationHeader;
        global Api.SessionHeader_element SessionHeader;
		private String CallOptions_hns = 'CallOptions=urn:tooling.soap.sforce.com';
        private String DisableFeedTrackingHeader_hns = 'DisableFeedTrackingHeader=urn:tooling.soap.sforce.com';
        private String DebuggingHeader_hns = 'DebuggingHeader=urn:tooling.soap.sforce.com';
        private String AllowFieldTruncationHeader_hns = 'AllowFieldTruncationHeader=urn:tooling.soap.sforce.com';
        private String SessionHeader_hns = 'SessionHeader=urn:tooling.soap.sforce.com';
        private String PackageVersionHeader_hns = 'PackageVersionHeader=urn:tooling.soap.sforce.com';
        private String DebuggingInfo_hns = 'DebuggingInfo=urn:tooling.soap.sforce.com';
        private String[] ns_map_type_info = new String[]{'urn:tooling.soap.sforce.com', 'Api'};


        global Api.ExecuteAnonymousResult executeAnonymous(String String_x) {
            Api.executeAnonymous_element request_x = new Api.executeAnonymous_element();
            Api.executeAnonymousResponse_element response_x;
            request_x.String_x = String_x;
            Map<String, Api.executeAnonymousResponse_element> response_map_x = new Map<String, Api.executeAnonymousResponse_element>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              '',
              'urn:tooling.soap.sforce.com',
              'executeAnonymous',
              'urn:tooling.soap.sforce.com',
              'executeAnonymousResponse',
              'Api.executeAnonymousResponse_element'}
            );
            response_x = response_map_x.get('response_x');
            return response_x.result;
        }
        global Api.QueryResult query(String queryString) {
            Api.query_element request_x = new Api.query_element();
            Api.queryResponse_element response_x;
            request_x.queryString = queryString;
            Map<String, Api.queryResponse_element> response_map_x = new Map<String, Api.queryResponse_element>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              '',
              'urn:tooling.soap.sforce.com',
              'query',
              'urn:tooling.soap.sforce.com',
              'queryResponse',
              'Api.queryResponse_element'}
            );
            response_x = response_map_x.get('response_x');
            return response_x.result;
        }
 
    }
}