import React from 'react'
import { Users, Plus, Search, Filter, ShieldCheck, Mail, Phone } from 'lucide-react'
import {
  PageHeader,
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  Badge,
  Button,
  Input,
} from '../components/common'

export function Employees() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Employees"
        subtitle="Manage food safety certifications, hygiene training records, and personnel assignments."
        badge={<Badge variant="info" size="sm">Module Ready</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Employees' }]}
        actions={
          <Button variant="primary" size="sm" icon={Plus}>
            Add Employee
          </Button>
        }
      />

      <Card>
        <CardHeader className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <CardTitle>Personnel & Food Handler Roster</CardTitle>
            <CardDescription>View certified staff, medical clearances, and hygiene credentials.</CardDescription>
          </div>
          <div className="flex items-center gap-2">
            <Input
              icon={Search}
              placeholder="Search employee or ID..."
              className="w-full sm:w-64"
            />
            <Button variant="secondary" size="sm" icon={Filter}>
              Filter
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="py-12 flex flex-col items-center justify-center text-center max-w-md mx-auto space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center border border-emerald-100">
              <Users className="w-6 h-6" />
            </div>
            <h4 className="text-base font-bold text-slate-800">Employee Management Ready</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              This module is set up with the standard FSMS design system. In upcoming steps, employee records, hygiene training certifications, and role-based assignments will be integrated.
            </p>
            <div className="pt-2">
              <Button variant="outline" size="sm" icon={Plus}>
                Configure Employee Fields
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
