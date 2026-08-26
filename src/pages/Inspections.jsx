import React from 'react'
import { ShieldCheck, Plus, Search, Calendar, Filter } from 'lucide-react'
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

export function Inspections() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Inspections"
        subtitle="Conduct on-site audits, CCP thermal verifications, and digital compliance logging."
        badge={<Badge variant="success" dot size="sm">Audit Ready</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Inspections' }]}
        actions={
          <Button variant="primary" size="sm" icon={Plus}>
            Start New Inspection
          </Button>
        }
      />

      <Card>
        <CardHeader className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <CardTitle>Inspection Records & Audit Trail</CardTitle>
            <CardDescription>Immutable inspection history with digital signatures and photo evidence.</CardDescription>
          </div>
          <div className="flex items-center gap-2">
            <Input
              icon={Search}
              placeholder="Search audit ID or auditor..."
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
              <ShieldCheck className="w-6 h-6" />
            </div>
            <h4 className="text-base font-bold text-slate-800">Inspections Engine Foundation</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              Design foundation ready. In subsequent steps, live inspection forms with auto-scoring, photo attachment, and instant non-conformance flag triggers will be linked.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
