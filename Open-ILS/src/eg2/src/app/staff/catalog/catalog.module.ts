import {NgModule} from '@angular/core';
import {StaffCommonModule} from '@eg/staff/common.module';
import {CatalogCommonModule} from '@eg/share/catalog/catalog-common.module';
import {CatalogRoutingModule} from './routing.module';
import {HoldsModule} from '@eg/staff/share/holds/holds.module';
import {HoldingsModule} from '@eg/staff/share/holdings/holdings.module';
import {BookingModule} from '@eg/staff/share/booking/booking.module';
import {CatalogComponent} from './catalog.component';
import {SearchFormComponent} from './search-form.component';
import {ResultsComponent} from './result/results.component';
import {RecordComponent} from './record/record.component';
import {CopiesComponent} from './record/copies.component';
import {ResultPaginationComponent} from './result/pagination.component';
import {ResultFacetsComponent} from './result/facets.component';
import {ResultRecordComponent} from './result/record.component';
import {StaffCatalogService} from './catalog.service';
import {RecordPaginationComponent} from './record/pagination.component';
import {RecordActionsComponent} from './record/actions.component';
import {BasketActionsComponent} from './basket-actions.component';
import {HoldComponent} from './hold/hold.component';
import {PartsComponent} from './record/parts.component';
import {PartMergeDialogComponent} from './record/part-merge-dialog.component';
import {BrowseComponent} from './browse.component';
import {BrowseResultsComponent} from './browse/results.component';
import {HoldingsMaintenanceComponent} from './record/holdings.component';
import {ConjoinedComponent} from './record/conjoined.component';
import {CnBrowseComponent} from './cnbrowse.component';
import {CnBrowseResultsComponent} from './cnbrowse/results.component';
import {MarcEditModule} from '@eg/staff/share/marc-edit/marc-edit.module';

@NgModule({
  declarations: [
    CatalogComponent,
    ResultsComponent,
    RecordComponent,
    CopiesComponent,
    SearchFormComponent,
    ResultRecordComponent,
    ResultFacetsComponent,
    ResultPaginationComponent,
    RecordPaginationComponent,
    RecordActionsComponent,
    BasketActionsComponent,
    HoldComponent,
    PartsComponent,
    PartMergeDialogComponent,
    BrowseComponent,
    BrowseResultsComponent,
    ConjoinedComponent,
    HoldingsMaintenanceComponent,
    CnBrowseComponent,
    CnBrowseResultsComponent
  ],
  imports: [
    StaffCommonModule,
    CatalogCommonModule,
    CatalogRoutingModule,
    HoldsModule,
    HoldingsModule,
    BookingModule,
    MarcEditModule
  ],
  providers: [
    StaffCatalogService
  ]
})

export class CatalogModule {

}
