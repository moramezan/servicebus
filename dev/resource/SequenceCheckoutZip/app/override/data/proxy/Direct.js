Ext.define('Checkout.override.data.proxy.Direct', {
    override: 'Ext.data.proxy.Direct',

    /**
     * Salesforce JavaScript Remoting uses none of these
     */
    directionParam: undefined,
    filterParam: undefined,
    groupDirectionParam: undefined,
    groupParam: undefined,
    idParam: undefined,
    limitParam: undefined,
    pageParam: undefined,
    sortParam: undefined,
    startParam: undefined,
    paramsAsHash: undefined,

    /**
     * Keyholing our invokation here:
     * @param {Ext.data.Operation} operation The Ext.data.Operation object
     */
    doRequest: function(operation) {
        var me = this,
            writer, request, action, params, args, api, fn, callback;

        if (!me.methodsResolved) {
            me.resolveMethods();
        }

        request = me.buildRequest(operation);
        action  = request.getAction();
        api     = me.getApi();

        if (api) {
            fn = api[action];
        }

        fn = fn || me.getDirectFn();

        //<debug>
        if (!fn) {
            Ext.Error.raise('[Bigass.data.proxy.Visualforce] No remote action specified for this proxy');
        }
        //</debug>

        writer = me.getWriter();

        if (writer && operation.allowWrite()) {
            request = writer.write(request);
        }

        // The weird construct below is due to historical way of handling extraParams;
        // they were mixed in with request data in ServerProxy.buildRequest() and were
        // inseparable after that point. This does not work well with CUD operations
        // so instead of using potentially poisoned request params we took the raw
        // JSON data as Direct function argument payload (but only for CUD!). A side
        // effect of that was that the request metadata (extraParams) was only available
        // for read operations.
        // We keep this craziness for backwards compatibility.
        if (action === 'read') {
            params = request.getParams();
        }
        else {
            params = [request.getJsonData()];
        }

        //arguments TODO paramOrder
        args = Ext.Object.getValues(params);

        //callback
        args.push(me.createRequestCallback(request, operation));

        //config
        args.push({
            escape: false, //let ExtJS handle output escaping
            buffer: true, //always leverage request/response grouping
            timeout: this.timeout //configure remoting timeout on proxy
        });

        request.setConfig({
            args: args,
            directFn: fn
        });

        fn.apply(window, args);

        // Store expects us to return something to indicate that the request
        // is pending; not doing so will make a buffered Store repeat the
        // requests over and over. See https://sencha.jira.com/browse/EXTJSIV-11757
        return request;
    },

    /**
     * @private
     * 
     * Upon success, RESPONSE will get handed off to {@link #extractResponseData}
     * The format of the RESPONSE object is per the remote method signature.
     * 
     * Upon failure, EVENT will get handed off to {@link #setException}
     * The format of the EVENT object is per http://www.salesforce.com/us/developer/docs/pages/Content/pages_js_remoting.htm#handling_remote_response
     * 
     * @param {Ext.data.Request} request The Request object
     * @param {Ext.data.Operation} operation The Operation being executed
     * @param {Function} callback The callback function to be called when the request completes.
     * @param {Object} scope The scope in which to execute the callback function
     * @return {Function} The callback function
     */
    createRequestCallback: function(request, operation){
        var me = this;

        /**
         * Keyholing our callback here. Note that on exception, RESPONSE is null so we pass EVENT.
         * @param {Array/Boolean/Number/Object/String} response per remote method return type
         * @param {Ext.direct.Transaction} event akin to {@link Ext.direct.RemotingProvider#getCallArgs}
         */
        return function(response, event) {
            me.processResponse(event.status, operation, request, response || event);
        };
    },

    /**
     * Identity function; the Visualforce remoting client does not expose us to any wrapper object
     * @param {Array/Boolean/Number/Object/String} response The server response per remote method return type
     * @return {Array/Boolean/Number/Object/String} The response data to be used by the reader
     */
    extractResponseData: function(response) {
        return response;
    },

    /**
     * Keyholing any exception handling here
     * @param {Ext.data.Operation} operation
     * @param {Ext.direct.Transaction} event akin to {@link Ext.direct.RemotingProvider#getCallArgs}
     */
    setException: function(operation, event) {
        //<debug>
        Ext.Msg.show({
            title:'Visualforce Remoting Exception in ' + event.action + '.' + event.method,
            msg: event.message + '<pre>\n\n' + event.where + '</pre>',
            buttons: [] //don't show buttons, events may inadvertently get bound to them!
        });
        //</debug>
        operation.setException(event.message);
    }

});