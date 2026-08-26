import React from 'react'
import { ClipboardCheck, Plus, Search, CheckSquare } from 'lucide-react'
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

export function Checklists() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Checklists"
        subtitle="Standard operating procedures (SOPs), sanitation inspection forms, and daily verification templates."
        badge={<Badge variant="info" size="sm">Template Engine</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Checklists' }]}
        actions={
          <Button variant="primary" size="sm" icon={Plus}>
            Create Checklist
          </Button>
        }
      />

      <Card>
        <CardHeader className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <CardTitle>Safety & Quality Checklists</CardTitle>
            <CardDescription>Customizable digital checklist templates with pass/fail and thermal validation criteria.</CardDescription>
          </div>
          <Input
            icon={Search}
            placeholder="Search checklists..."
            className="w-full sm:w-64"
          />
        </CardHeader>
        <CardContent>
          <div className="py-12 flex flex-col items-center justify-center text-center max-w-md mx-auto space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center border border-emerald-100">
              <ClipboardCheck className="w-6 h-6" />
            </div>
            <h4 className="text-base font-bold text-slate-800">Checklists Module Foundation</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              Ready for checklist builder implementation, pre-shift opening checks, sanitation schedules, and allergen clean-down verifications.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
