import React from 'react'
import { Building2, Plus, Search, Layers } from 'lucide-react'
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

export function Departments() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Departments"
        subtitle="Organize processing plants, packaging units, quality control labs, and storage zones."
        badge={<Badge variant="neutral" size="sm">Module Ready</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Departments' }]}
        actions={
          <Button variant="primary" size="sm" icon={Plus}>
            New Department
          </Button>
        }
      />

      <Card>
        <CardHeader className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <CardTitle>Facility Zones & Departments</CardTitle>
            <CardDescription>Hierarchical zone mapping for HACCP hazard analysis.</CardDescription>
          </div>
          <div className="flex items-center gap-2">
            <Input
              icon={Search}
              placeholder="Search facility zone..."
              className="w-full sm:w-64"
            />
          </div>
        </CardHeader>
        <CardContent>
          <div className="py-12 flex flex-col items-center justify-center text-center max-w-md mx-auto space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center border border-emerald-100">
              <Building2 className="w-6 h-6" />
            </div>
            <h4 className="text-base font-bold text-slate-800">Departments & Zones Initialized</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              Foundation established. Future steps will allow defining processing zones, hygiene barrier zones (Low/Medium/High care), and zone-specific safety supervisors.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
