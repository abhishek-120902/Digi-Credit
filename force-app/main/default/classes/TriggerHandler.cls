//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

public virtual class TriggerHandler {
    
    // Static map to prevent recursive calls
    private static Map<String, LoopCount> loopCountMap;
    private static Set<String> bypassedHandlers;
    
    // Instance variables
    protected TriggerContext context;
    protected Boolean isTriggerExecuting;
    
    static {
        loopCountMap = new Map<String, LoopCount>();
        bypassedHandlers = new Set<String>();
    }
    
    public TriggerHandler() {
        this.setTriggerContext();
    }
    
    /**
     * Main entry point for trigger execution
     */
    public void run() {
        if (!validateRun()) {
            return;
        }
        
        addToLoopCount();
        
        // Dispatch to appropriate method based on trigger context
        if (this.context == TriggerContext.BEFORE_INSERT) {
            this.beforeInsert();
        } else if (this.context == TriggerContext.BEFORE_UPDATE) {
            this.beforeUpdate();
        } else if (this.context == TriggerContext.BEFORE_DELETE) {
            this.beforeDelete();
        } else if (this.context == TriggerContext.AFTER_INSERT) {
            this.afterInsert();
        } else if (this.context == TriggerContext.AFTER_UPDATE) {
            this.afterUpdate();
        } else if (this.context == TriggerContext.AFTER_DELETE) {
            this.afterDelete();
        } else if (this.context == TriggerContext.AFTER_UNDELETE) {
            this.afterUndelete();
        }
    }
    
    /**
     * Virtual methods to be overridden by concrete implementations
     */
    protected virtual void beforeInsert() {}
    protected virtual void beforeUpdate() {}
    protected virtual void beforeDelete() {}
    protected virtual void afterInsert() {}
    protected virtual void afterUpdate() {}
    protected virtual void afterDelete() {}
    protected virtual void afterUndelete() {}
    
    /**
     * Bypass a specific trigger handler
     * @param handlerName Name of the handler to bypass
     */
    public static void bypass(String handlerName) {
        TriggerHandler.bypassedHandlers.add(handlerName);
    }
    
    /**
     * Clear bypass for a specific trigger handler
     * @param handlerName Name of the handler to clear bypass for
     */
    public static void clearBypass(String handlerName) {
        TriggerHandler.bypassedHandlers.remove(handlerName);
    }
    
    /**
     * Check if a handler is bypassed
     * @param handlerName Name of the handler to check
     * @return Boolean indicating if handler is bypassed
     */
    public static Boolean isBypassed(String handlerName) {
        return TriggerHandler.bypassedHandlers.contains(handlerName);
    }
    
    /**
     * Clear all bypassed handlers
     */
    public static void clearAllBypasses() {
        TriggerHandler.bypassedHandlers.clear();
    }
    
    /**
     * Set maximum loop count for a handler
     * @param handlerName Name of the handler
     * @param max Maximum number of loops allowed
     */
    public static void setMaxLoopCount(String handlerName, Integer max) {
        String name = handlerName.toLowerCase();
        if (!TriggerHandler.loopCountMap.containsKey(name)) {
            TriggerHandler.loopCountMap.put(name, new LoopCount(max));
        } else {
            TriggerHandler.loopCountMap.get(name).setMax(max);
        }
    }
    
    /**
     * Clear loop count for a handler
     * @param handlerName Name of the handler
     */
    public static void clearLoopCount(String handlerName) {
        String name = handlerName.toLowerCase();
        TriggerHandler.loopCountMap.remove(name);
    }
    
    /**
     * Validate if trigger should run
     * @return Boolean indicating if trigger should execute
     */
    private Boolean validateRun() {
        if (!this.isTriggerExecuting || this.context == null) {
            throw new TriggerHandlerException('Trigger handler called outside of Trigger execution');
        }
        
        String handlerName = getHandlerName();
        if (TriggerHandler.bypassedHandlers.contains(handlerName)) {
            return false;
        }
        
        return true;
    }
    
    /**
     * Set the trigger context based on current trigger state
     */
    private void setTriggerContext() {
        this.isTriggerExecuting = Trigger.isExecuting;
        
        if (!this.isTriggerExecuting) {
            return;
        }
        
        if (Trigger.isBefore && Trigger.isInsert) {
            this.context = TriggerContext.BEFORE_INSERT;
        } else if (Trigger.isBefore && Trigger.isUpdate) {
            this.context = TriggerContext.BEFORE_UPDATE;
        } else if (Trigger.isBefore && Trigger.isDelete) {
            this.context = TriggerContext.BEFORE_DELETE;
        } else if (Trigger.isAfter && Trigger.isInsert) {
            this.context = TriggerContext.AFTER_INSERT;
        } else if (Trigger.isAfter && Trigger.isUpdate) {
            this.context = TriggerContext.AFTER_UPDATE;
        } else if (Trigger.isAfter && Trigger.isDelete) {
            this.context = TriggerContext.AFTER_DELETE;
        } else if (Trigger.isAfter && Trigger.isUndelete) {
            this.context = TriggerContext.AFTER_UNDELETE;
        }
    }
    
    /**
     * Add to loop count and check for maximum exceeded
     */
    private void addToLoopCount() {
        String handlerName = getHandlerName().toLowerCase();
        if (TriggerHandler.loopCountMap.containsKey(handlerName)) {
            Boolean exceeded = TriggerHandler.loopCountMap.get(handlerName).increment();
            if (exceeded) {
                Integer max = TriggerHandler.loopCountMap.get(handlerName).max;
                throw new TriggerHandlerException('Maximum loop count of ' + String.valueOf(max) + ' reached in ' + handlerName);
            }
        }
    }
    
    /**
     * Get the name of the current handler
     * @return String name of the handler class
     */
    private String getHandlerName() {
        return String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    }
    
    /**
     * Enum for trigger contexts
     */
    private enum TriggerContext {
        BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
        AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE, AFTER_UNDELETE
    }
    
    /**
     * Inner class to track loop counts
     */
    private class LoopCount {
        private Integer max;
        private Integer count;
        
        public LoopCount() {
            this.max = 5;
            this.count = 0;
        }
        
        public LoopCount(Integer max) {
            this.max = max;
            this.count = 0;
        }
        
        public Boolean increment() {
            this.count++;
            return this.count >= this.max;
        }
        
        public Integer getMax() {
            return this.max;
        }
        
        public Integer getCount() {
            return this.count;
        }
        
        public void setMax(Integer max) {
            this.max = max;
        }
    }
    
    /**
     * Custom exception for trigger handler errors
     */
    public class TriggerHandlerException extends Exception {}
}

//__________________________GenAI: Generated code ends here______________________________
