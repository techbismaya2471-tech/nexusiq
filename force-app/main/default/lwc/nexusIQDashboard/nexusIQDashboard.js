import { LightningElement, track, wire } from 'lwc';
import getCircuitBreakerStatus from '@salesforce/apex/NexusIQDashboardController.getCircuitBreakerStatus';
import getRecentLogs from '@salesforce/apex/NexusIQDashboardController.getRecentLogs';
import getRecentSagas from '@salesforce/apex/NexusIQDashboardController.getRecentSagas';
import getDashboardSummary from '@salesforce/apex/NexusIQDashboardController.getDashboardSummary';

export default class NexusIQDashboard extends LightningElement {
    @track circuitBreakers = [];
    @track recentLogs = [];
    @track recentSagas = [];
    @track summary = {};
    @track isLoading = true;
    @track error;
    @track lastRefreshed = '';

    refreshInterval;

    connectedCallback() {
        this.loadAllData();
        this.refreshInterval = setInterval(() => {
            this.loadAllData();
        }, 30000);
    }

    disconnectedCallback() {
        clearInterval(this.refreshInterval);
    }

    loadAllData() {
        this.isLoading = true;
        this.lastRefreshed = new Date().toLocaleTimeString('en-IN', { timeZone: 'Asia/Kolkata' });

        Promise.all([
            getCircuitBreakerStatus(),
            getRecentLogs(),
            getRecentSagas(),
            getDashboardSummary()
        ])
        .then(([cbs, logs, sagas, summary]) => {
            this.circuitBreakers = cbs.map(cb => ({
                ...cb,
                statusClass: this.getStatusClass(cb.status),
                badgeClass: this.getBadgeClass(cb.status),
                isClosed: cb.status === 'CLOSED',
                isOpen: cb.status === 'OPEN',
                isHalfOpen: cb.status === 'HALF_OPEN'
            }));

            this.recentLogs = logs.map(log => ({
                ...log,
                isSuccess: log.status === 'SUCCESS',
                isFailed: log.status === 'FAILED',
                statusClass: log.status === 'SUCCESS' ? 'log-success' : 'log-failed'
            }));

            this.recentSagas = sagas.map(saga => ({
                ...saga,
                isRunning: saga.status === 'RUNNING',
                isCompleted: saga.status === 'COMPLETED',
                isFailed: saga.status === 'FAILED',
                progressPercent: saga.totalSteps > 0 ?
                        Math.round((saga.currentStep / saga.totalSteps) * 100) : 0,
                        progressStyle: 'width:' + (saga.totalSteps > 0 ?
                        Math.round((saga.currentStep / saga.totalSteps) * 100) : 0) + '%'
            }));

            this.summary = summary;
            this.isLoading = false;
            this.error = undefined;
        })
        .catch(error => {
            this.error = error.body?.message || 'Error loading dashboard data';
            this.isLoading = false;
        });
    }

    getStatusClass(status) {
        if(status === 'CLOSED')    return 'card-closed';
        if(status === 'OPEN')      return 'card-open';
        if(status === 'HALF_OPEN') return 'card-half';
        return 'card-closed';
    }

    getBadgeClass(status) {
        if(status === 'CLOSED')    return 'badge-closed';
        if(status === 'OPEN')      return 'badge-open';
        if(status === 'HALF_OPEN') return 'badge-half';
        return 'badge-closed';
    }

    handleRefresh() {
        this.loadAllData();
    }
}