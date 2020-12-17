import {Component, OnInit} from '@angular/core';
import {ActivatedRoute} from '@angular/router';
import {IdlService} from '@eg/core/idl.service';
import {NetService} from '@eg/core/net.service';

/**
 * Generic IDL class editor page.
 */

@Component({
    template: `
      <eg-title i18n-prefix prefix="{{classLabel}} Administration">
      </eg-title>
      <eg-staff-banner bannerText="{{classLabel}} Configuration" i18n-bannerText>
      </eg-staff-banner>
      <div class="alert alert-info" i18n>
        Entries in this table contain the distance in miles between shipping locations. Shipping hubs are configured from the Orginizational Units page. These numbers are used for sorting hold targets during inter-library lending. Entries can be created manually or calculated using the free Bing Maps API if a key has been set up in the opensrf core config file. <b>Running the API will remove any existing data from this table</b>.    
      </div>
      <button [disabled]="calculating" class="btn btn-outline-dark" (click)="calculateDistances()">Calculate with API</button>
      <eg-progress-inline *ngIf="calculating" ></eg-progress-inline>
      <br>
      <br>
      <eg-admin-page persistKeyPfx="{{persistKeyPfx}}" idlClass="{{idlClass}}"
        configLinkBasePath="{{configLinkBasePath}}"
        readonlyFields="{{readonlyFields}}"
        [disableOrgFilter]="disableOrgFilter"></eg-admin-page>
    `
})

export class OrgUnitShippingHubDistanceComponent implements OnInit {

    idlClass: string;
    classLabel: string;
    persistKeyPfx: string;
    readonlyFields = '';
    configLinkBasePath = '/staff/admin';

    // API is currently calculating
    calculating : boolean;
    // Tell the admin page to disable and hide the automagic org unit filter
    disableOrgFilter: boolean;

    constructor(
        private route: ActivatedRoute,
        private idl: IdlService,
        private net: NetService
    ) {
    }

    ngOnInit() {
        let schema = this.route.snapshot.paramMap.get('schema');       
        if (!schema) {
            // Allow callers to pass the schema via static route data
            const data = this.route.snapshot.data[0];
            if (data) { schema = data.schema; }
        }
        let table = this.route.snapshot.paramMap.get('table');
        if (!table) {
            const data = this.route.snapshot.data[0];
            if (data) { table = data.table; }
        }
        const fullTable = schema + '.' + table;

        // Set the prefix to "server", "local", "workstation",
        // extracted from the URL path.
        // For admin pages that use none of these, avoid setting
        // the prefix because that will cause it to double-up.
        // e.g. eg.grid.acq.acq.cancel_reason
        this.persistKeyPfx = this.route.snapshot.parent.url[0].path;
        const selfPrefixers = ['acq', 'booking'];
        if (selfPrefixers.indexOf(this.persistKeyPfx) > -1) {
            // ACQ is a special case, because unlike 'server', 'local',
            // 'workstation', the schema ('acq') is the root of the path.
            this.persistKeyPfx = '';
        } else {
            this.configLinkBasePath += '/' + this.persistKeyPfx;
        }

        // Pass the readonlyFields param if available
        if (this.route.snapshot.data && this.route.snapshot.data[0]) {
            // snapshot.data is a HASH.
            const data = this.route.snapshot.data[0];

            if (data.readonlyFields) {
                this.readonlyFields = data.readonlyFields;
            }

            if (data.disableOrgFilter) {
                this.disableOrgFilter = true;
            }
        }

        Object.keys(this.idl.classes).forEach(class_ => {
            const classDef = this.idl.classes[class_];
            if (classDef.table === fullTable) {
                this.idlClass = class_;
                this.classLabel = classDef.label;
            }
        });

        if (!this.idlClass) {
            throw new Error('Unable to find IDL class for table ' + fullTable);
        }
        this.calculating = false;
    }
    
    calculateDistances(){
        this.calculating = true;
            this.net.request(
                'open-ils.vicinity-calculator',
                'open-ils.vicinity-calculator.build-distance-matrix'
            ).subscribe(
                n => {this.calculating = false; location.reload();},
                err  => {alert('API failed to calculate' + err);this.calculating = false;}
            );
    }
}


