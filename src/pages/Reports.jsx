import React from 'react'
import { BarChart3, FileDown, Calendar, Filter } from 'lucide-react'
import {
  PageHeader,
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  Badge,
  Button,
} from '../components/common'

export function Reports() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Reports & Analytics"
        subtitle="Export regulatory compliance certificates, trend charts, and audit summary packs."
        badge={<Badge variant="purple" size="sm">Audit Reporting</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Reports' }]}
        actions={
          <Button variant="primary" size="sm" icon={FileDown}>
            Download PDF Report
          </Button>
        }
      />

      <Card>
        <CardHeader className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <CardTitle>Compliance Intelligence & GFSI Analytics</CardTitle>
            <CardDescription>Automated monthly reports for USDA, FDA, BRCGS, and FSSC 22000 audits.</CardDescription>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="secondary" size="sm" icon={Calendar}>
              Last 30 Days
            </Button>
            <Button variant="outline" size="sm" icon={Filter}>
              Filter
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="py-12 flex flex-col items-center justify-center text-center max-w-md mx-auto space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-purple-50 text-purple-600 flex items-center justify-center border border-purple-100">
              <BarChart3 className="w-6 h-6" />
            </div>
            <h4 className="text-base font-bold text-slate-800">Reporting Engine Foundation</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              Design system connected. Recharts and PDF exporter pipeline will be configured in the analytics phase.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
