import React from 'react'
import { AlertTriangle, Plus, Search, CheckCircle2, Clock } from 'lucide-react'
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

export function Capa() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="CAPA (Corrective & Preventive Actions)"
        subtitle="Track root cause investigations, assign corrective tasks, and verify preventive resolutions."
        badge={<Badge variant="warning" dot size="sm">3 Open Tasks</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'CAPA' }]}
        actions={
          <Button variant="primary" size="sm" icon={Plus}>
            New CAPA Incident
          </Button>
        }
      />

      <Card>
        <CardHeader className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <CardTitle>Corrective Action Incident Log</CardTitle>
            <CardDescription>ISO 22000 compliant 8D / 5-Why root cause resolution workflow.</CardDescription>
          </div>
          <Input
            icon={Search}
            placeholder="Search CAPA ticket #..."
            className="w-full sm:w-64"
          />
        </CardHeader>
        <CardContent>
          <div className="py-12 flex flex-col items-center justify-center text-center max-w-md mx-auto space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-amber-50 text-amber-600 flex items-center justify-center border border-amber-100">
              <AlertTriangle className="w-6 h-6" />
            </div>
            <h4 className="text-base font-bold text-slate-800">CAPA Workflow Foundation</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              Foundation established. Next iterations will include incident ticketing, escalation deadlines, root cause analysis forms, and manager sign-off stages.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
