#!/usr/bin/env python3
import argparse,json
p=argparse.ArgumentParser(description='Scenario estimate, not measured billing. Supply verified rates.')
p.add_argument('--node-monthly',type=float,required=True);p.add_argument('--lb-monthly',type=float,required=True)
p.add_argument('--extra-node-hours',type=float,default=40);p.add_argument('--hours-per-month',type=float,default=730)
p.add_argument('--other-monthly',type=float,default=0);a=p.parse_args()
if min(a.node_monthly,a.lb_monthly,a.extra_node_hours,a.other_monthly)<0 or a.hours_per_month<=0 or a.extra_node_hours>a.hours_per_month:p.error('Invalid non-negative rates or hours')
baseline=2*a.node_monthly+a.lb_monthly+a.other_monthly
fixed=3*a.node_monthly+a.lb_monthly+a.other_monthly
scaled=baseline+a.node_monthly/a.hours_per_month*a.extra_node_hours
print(json.dumps({'type':'illustrative estimate using user-supplied rates','inputs':vars(a),'two_node_baseline':round(baseline,2),'three_nodes_full_month':round(fixed,2),'two_nodes_plus_burst':round(scaled,2),'scenario_difference':round(fixed-scaled,2),'exclusions':'Taxes, transfer overages, storage, registry, HA control plane unless included in other-monthly. Uses monthly-rate/hour approximation, not provider invoice logic.'},indent=2))
