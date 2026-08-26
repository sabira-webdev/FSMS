import React from 'react'
import { Settings as SettingsIcon, Save, Sliders, BellRing, Database } from 'lucide-react'
import {
  PageHeader,
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
  Badge,
  Button,
  Input,
} from '../components/common'

export function Settings() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Settings"
        subtitle="Configure food safety thresholds, audit intervals, notification triggers, and enterprise standards."
        badge={<Badge variant="neutral" size="sm">System Config</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Settings' }]}
        actions={
          <Button variant="primary" size="sm" icon={Save}>
            Save Preferences
          </Button>
        }
      />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Food Safety Compliance Standards</CardTitle>
            <CardDescription>Regulatory frameworks active for your organization.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex items-center justify-between p-3 rounded-lg bg-slate-50 border border-slate-200">
              <div>
                <p className="text-xs font-semibold text-slate-800">HACCP 7 Principles</p>
                <p className="text-[11px] text-slate-500">Hazard Analysis Critical Control Points</p>
              </div>
              <Badge variant="success" size="sm">Active</Badge>
            </div>
            <div className="flex items-center justify-between p-3 rounded-lg bg-slate-50 border border-slate-200">
              <div>
                <p className="text-xs font-semibold text-slate-800">ISO 22000:2018</p>
                <p className="text-[11px] text-slate-500">Food Safety Management System Standards</p>
              </div>
              <Badge variant="success" size="sm">Active</Badge>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>System Information</CardTitle>
            <CardDescription>Frontend foundation status.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="p-3 rounded-lg bg-emerald-50/50 border border-emerald-100 text-xs space-y-1">
              <div className="flex justify-between">
                <span className="text-slate-500">Application:</span>
                <span className="font-semibold text-slate-900">Food Safety Management System (FSMS)</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Theme:</span>
                <span className="font-semibold text-emerald-700">Green Enterprise</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Phase:</span>
                <span className="font-semibold text-slate-900">Step 1: Frontend Foundation</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
