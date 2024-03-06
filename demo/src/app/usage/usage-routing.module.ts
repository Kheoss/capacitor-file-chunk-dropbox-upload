import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';

import { UsagePage } from './usage.page';

const routes: Routes = [
  {
    path: '',
    component: UsagePage,
  },
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule],
})
export class UsagePageRoutingModule {}
