public virtual class NexusIQServiceBase {
    
    protected String correlationId;
    
    public NexusIQServiceBase() {
        this.correlationId = NexusIQUtils.generateCorrelationId();
        NexusIQUtils.log(correlationId, 'Service initialized: ' + this.toString());
    }
    
    // Every service call goes through this — logs start and end
    protected Object execute(String stepName, Object payload) {
        NexusIQUtils.log(correlationId, 'START: ' + stepName);
        try {
            Object result = run(stepName, payload);
            NexusIQUtils.log(correlationId, 'SUCCESS: ' + stepName);
            return result;
        } catch(Exception e) {
            NexusIQUtils.log(correlationId, 'FAILED: ' + stepName + ' | Error: ' + e.getMessage());
            throw e;
        }
    }
    
    // Child classes will override this
    protected virtual Object run(String stepName, Object payload) {
        return null;
    }
}