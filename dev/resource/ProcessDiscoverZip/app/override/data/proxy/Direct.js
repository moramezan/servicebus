Ext.define('Discover.override.data.proxy.Direct', {
    override: 'Ext.data.proxy.Direct',
    
    requires: ['Ext.direct.RemotingMethod'], //We are pinching the implementation of getArgs
    
    /* End Definitions */
    
    /**
     * @cfg {String} [directionParam="dir"]
     * The name of the direction parameter to send in a request. **This is only used when simpleSortMode is set to
     * true.**
     */
    directionParam: undefined,

    /**
     * @cfg {String} [filterParam="filter"]
     * The name of the 'filter' parameter to send in a request. Defaults to 'filter'. Set this to undefined if you don't
     * want to send a filter parameter.
     */
    filterParam: undefined,

    /**
     * @cfg {String} [groupDirectionParam="groupDir"]
     * The name of the direction parameter to send in a request. **This is only used when simpleGroupMode is set to
     * true.**
     */
    groupDirectionParam: undefined,

    /**
     * @cfg {String} [groupParam="group"]
     * The name of the 'group' parameter to send in a request. Defaults to 'group'. Set this to undefined if you don't
     * want to send a group parameter.
     */
    groupParam: undefined,

    /**
     * @cfg {String} [idParam="id"]
     * The name of the parameter which carries the id of the entity being operated upon.
     */
    idParam: undefined,

    /**
     * @cfg {String} [limitParam="limit"]
     * The name of the 'limit' parameter to send in a request. Defaults to 'limit'. Set this to undefined if you don't
     * want to send a limit parameter.
     */
    limitParam: undefined,

    /**
     * @cfg {String} [pageParam="page"]
     * The name of the 'page' parameter to send in a request. Defaults to 'page'. Set this to undefined if you don't
     * want to send a page parameter.
     */
    pageParam: undefined,

    /**
     * @cfg {String} [sortParam="sort"]
     * The name of the 'sort' parameter to send in a request. Defaults to 'sort'. Set this to undefined if you don't
     * want to send a sort parameter.
     */
    sortParam: undefined,

    /**
     * @cfg {String} [startParam="start"]
     * The name of the 'start' parameter to send in a request. Defaults to 'start'. Set this to undefined if you don't
     * want to send a start parameter.
     */
    startParam: undefined,

    /**
     * @cfg {Boolean} paramsAsHash
     * Lose hash option; VFRM parameters are unnamed
     */
    paramsAsHash: undefined,

    /**
     * Keyholing our invokation here:
     * @param {Ext.data.Operation} operation The Ext.data.Operation object
     * @param {Function} callback The callback function to call when the Operation has completed
     * @param {Object} scope The scope in which to execute the callback
     */
    doRequest: function(operation, callback, scope) {
        var
            me = this,
            writer = me.getWriter(),
            request = me.buildRequest(operation),
            fn = me.api[request.getAction()]  || me.directFn,
            params = request.getParams(),
            args = [],
            data = []
        ;
        
        //<debug>
        if (!fn) Ext.Error.raise('[Bigass.data.proxy.Visualforce] No direct function specified for this proxy');
        //</debug>

        if (operation.allowWrite()) {
            request = writer.write(request);
        }

        if (operation.getAction() == 'read') {
            // We need to pass params (thanks Paco)
            var method = Ext.create('Ext.direct.RemotingMethod', {params: Ext.Object.getSize(me.paramOrder || params)});
            data = Ext.Object.getValues(method.getArgs(params, me.paramOrder || Ext.Object.getKeys(params), false));
            if (Ext.Object.getSize(params) != data.length) Ext.Error.raise('[Bigass.data.proxy.Visualforce] paramOrder must account for exactly ' + data.length + ' parameters');
        } else {
            data.push(request.getJsonData());
        }

        Ext.apply(request, {
            args: args,
            directFn: fn
        });

        var handler = me.createRequestCallback(request, operation, callback, scope);

        //method, eg 'ns.RemoteController.method' per {!$RemoteAction.RemoteController.method}
        args.push(fn);

        //argument(s)
        args.push.apply(args, data);

        //callback
        args.push(handler);

        //config
        args.push({
            escape: false, //let ExtJS handle output escaping
            buffer: true, //always leverage request/response grouping
            timeout: this.timeout //configure remoting timeout on proxy
        });

        //per Visualforce.remoting.Manager.invokeAction(method, argument(s) [...], callback, config)
        Visualforce.remoting.Manager.invokeAction.apply(Visualforce.remoting.Manager, args);
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
    createRequestCallback: function(request, operation, callback, scope) {
        var me = this;

        /**
         * Keyholing our callback here. Note that on exception, RESPONSE is null so we pass EVENT.
         * @param {Array/Boolean/Number/Object/String} response per remote method return type
         * @param {Ext.direct.Transaction} event akin to {@link Ext.direct.RemotingProvider#getCallArgs}
         */
        return function(response, event) {
            me.processResponse(event.status, operation, request, response || event, callback, scope);
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