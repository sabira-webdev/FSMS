import React from 'react'
import {
  ShieldCheck,
  ClipboardList,
  AlertOctagon,
  CheckCircle2,
  Clock,
  ArrowUpRight,
  Plus,
  FileDown,
  ThermometerSnowflake,
  Sparkles,
  Layers,
  Search,
} from 'lucide-react'
import {
  PageHeader,
  StatCard,
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
  Badge,
  Button,
  Alert,
} from '../components/common'
import { Link } from 'react-router-dom'

/**
 * Dashboard Page - Showcase of FSMS Enterprise Design System
 */
export function Dashboard() {
  const recentInspections = [
    {
      id: 'INS-2026-084',
      facility: 'Cold Storage Unit 3 (Dairy & Meat)',
      auditor: 'Jabir P K',
      date: 'Today, 09:30 AM',
      score: '98%',
      status: 'Passed',
      badgeVariant: 'success',
    },
    {
      id: 'INS-2026-083',
      facility: 'Packaging Line 2 - High Care',
      auditor: 'David Kumar',
      date: 'Today, 08:15 AM',
      score: '91%',
      status: 'Passed',
      badgeVariant: 'success',
    },
    {
      id: 'INS-2026-082',
      facility: 'Raw Material Receiving Bay A',
      auditor: 'Elena Rostova',
      date: 'Yesterday, 04:45 PM',
      score: '74%',
      status: 'CAPA Required',
      badgeVariant: 'danger',
    },
    {
      id: 'INS-2026-081',
      facility: 'Water Filtration & Sanitize Station',
      auditor: 'Sarah Jenkins',
      date: 'Yesterday, 02:00 PM',
      score: '88%',
      status: 'In Review',
      badgeVariant: 'warning',
    },
  ]

  const criticalControlPoints = [
    {
      name: 'CCP-1: Meat Blast Chiller #1',
      target: '-18.0°C to -22.0°C',
      current: '-20.4°C',
      status: 'Optimal',
      variant: 'success',
    },
    {
      name: 'CCP-2: Pasteurized Milk Holding Vat',
      target: '< 4.0°C',
      current: '3.2°C',
      status: 'Optimal',
      variant: 'success',
    },
    {
      name: 'CCP-3: Metal Detector Line A',
      target: '1.2mm Fe / 1.5mm Non-Fe',
      current: 'Passed Test',
      status: 'Verified',
      variant: 'info',
    },
  ]

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <PageHeader
        title="Food Safety Operations"
        subtitle="Real-time quality assurance, HACCP compliance monitoring, and inspection readiness."
        badge={
          <Badge variant="success" dot size="sm">
            ISO 22000 & HACCP Compliant
          </Badge>
        }
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Dashboard' }]}
        actions={
          <>
            <Button
              variant="secondary"
              size="sm"
              icon={FileDown}
            >
              Export Report
            </Button>
            <Link to="/inspections">
              <Button
                variant="primary"
                size="sm"
                icon={Plus}
              >
                New Inspection
              </Button>
            </Link>
          </>
        }
      />

      {/* Compliance Banner */}
      <Alert
        type="success"
        title="Facility Quality Status: 100% Audit Readiness"
        onDismiss={() => { }}
      >
        All Critical Control Points (CCPs) are operating within safe regulatory limits. Next scheduled GFSI internal audit in 5 days.
      </Alert>

      {/* KPI Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Overall Compliance"
          value="98.4%"
          change="+1.8%"
          changeType="increase"
          changeLabel="vs last month"
          icon={ShieldCheck}
          iconBg="bg-emerald-50 text-emerald-600 border-emerald-200"
        />
        <StatCard
          title="Inspections Completed"
          value="14 / 16"
          change="87.5%"
          changeType="increase"
          changeLabel="daily target"
          icon={ClipboardList}
          iconBg="bg-blue-50 text-blue-600 border-blue-200"
        />
        <StatCard
          title="Open CAPA Actions"
          value="3"
          change="-2"
          changeType="decrease"
          changeLabel="from last week"
          icon={AlertOctagon}
          iconBg="bg-amber-50 text-amber-600 border-amber-200"
        />
        <StatCard
          title="Active Checklists"
          value="24"
          change="100%"
          changeType="neutral"
          changeLabel="digitalized"
          icon={Layers}
          iconBg="bg-purple-50 text-purple-600 border-purple-200"
        />
      </div>

      {/* Main Grid: Recent Activity & Critical Control Points */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Recent Inspections Table */}
        <div className="lg:col-span-2 space-y-6">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <div>
                <CardTitle>Recent Facility Inspections</CardTitle>
                <CardDescription>Live log of hygiene, sanitation, and temperature checks.</CardDescription>
              </div>
              <Link to="/inspections">
                <Button variant="ghost" size="sm" icon={ArrowUpRight} iconPosition="right">
                  View All
                </Button>
              </Link>
            </CardHeader>
            <CardContent className="p-0">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs sm:text-sm">
                  <thead className="bg-slate-50 text-slate-600 text-[11px] uppercase tracking-wider font-semibold border-b border-slate-100">
                    <tr>
                      <th className="px-5 py-3">Code / Facility</th>
                      <th className="px-5 py-3">Auditor</th>
                      <th className="px-5 py-3">Score</th>
                      <th className="px-5 py-3">Status</th>
                      <th className="px-5 py-3 text-right">Timestamp</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 font-normal">
                    {recentInspections.map((row) => (
                      <tr key={row.id} className="hover:bg-slate-50/70 transition-colors">
                        <td className="px-5 py-3.5">
                          <div className="font-semibold text-slate-900">{row.id}</div>
                          <div className="text-xs text-slate-500">{row.facility}</div>
                        </td>
                        <td className="px-5 py-3.5 text-slate-700 font-medium">{row.auditor}</td>
                        <td className="px-5 py-3.5">
                          <span className="font-bold text-slate-900">{row.score}</span>
                        </td>
                        <td className="px-5 py-3.5">
                          <Badge variant={row.badgeVariant} dot size="sm">
                            {row.status}
                          </Badge>
                        </td>
                        <td className="px-5 py-3.5 text-right text-slate-500 text-xs">
                          {row.date}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
            <CardFooter>
              <span className="text-xs text-slate-500">Showing last 4 logs from shift A</span>
              <Link to="/inspections" className="text-xs font-semibold text-emerald-700 hover:text-emerald-800">
                Run Audit Checklist &rarr;
              </Link>
            </CardFooter>
          </Card>

          {/* Quick Action Bar */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <Link to="/checklists" className="block">
              <Card hover className="p-4 flex items-center gap-3.5 border-dashed hover:border-emerald-500">
                <div className="p-2.5 rounded-xl bg-emerald-50 text-emerald-600 shrink-0">
                  <ClipboardList className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="text-sm font-semibold text-slate-800">Checklists</h4>
                  <p className="text-xs text-slate-500">Execute daily sanitization</p>
                </div>
              </Card>
            </Link>

            <Link to="/capa" className="block">
              <Card hover className="p-4 flex items-center gap-3.5 border-dashed hover:border-amber-500">
                <div className="p-2.5 rounded-xl bg-amber-50 text-amber-600 shrink-0">
                  <AlertOctagon className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="text-sm font-semibold text-slate-800">Log CAPA</h4>
                  <p className="text-xs text-slate-500">Report non-conformance</p>
                </div>
              </Card>
            </Link>

            <Link to="/reports" className="block">
              <Card hover className="p-4 flex items-center gap-3.5 border-dashed hover:border-blue-500">
                <div className="p-2.5 rounded-xl bg-blue-50 text-blue-600 shrink-0">
                  <Sparkles className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="text-sm font-semibold text-slate-800">Audits</h4>
                  <p className="text-xs text-slate-500">Generate compliance docs</p>
                </div>
              </Card>
            </Link>
          </div>
        </div>

        {/* Right 1 Col: CCP Monitor & Quality Metrics */}
        <div className="space-y-6">
          {/* Critical Control Points Monitoring */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="flex items-center gap-2">
                  <ThermometerSnowflake className="w-4 h-4 text-emerald-600" />
                  CCP Live Telemetry
                </CardTitle>
                <Badge variant="success" dot size="sm">
                  Active
                </Badge>
              </div>
              <CardDescription>Critical thermal & contamination limit points.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3.5 pt-2">
              {criticalControlPoints.map((ccp, idx) => (
                <div
                  key={idx}
                  className="p-3 rounded-xl bg-slate-50 border border-slate-100 space-y-1.5"
                >
                  <div className="flex items-center justify-between text-xs">
                    <span className="font-semibold text-slate-800">{ccp.name}</span>
                    <Badge variant={ccp.variant} size="sm">
                      {ccp.status}
                    </Badge>
                  </div>
                  <div className="flex items-center justify-between text-xs text-slate-500">
                    <span>Limit: {ccp.target}</span>
                    <span className="font-bold text-slate-900">{ccp.current}</span>
                  </div>
                </div>
              ))}
            </CardContent>
            <CardFooter>
              <Link to="/reports" className="w-full">
                <Button variant="outline" size="sm" className="w-full">
                  Sensor Logs & Calibration
                </Button>
              </Link>
            </CardFooter>
          </Card>

          {/* Standards Compliance Card */}
          <Card className="bg-gradient-to-br from-emerald-900 to-slate-900 text-white border-0">
            <CardContent className="p-5 space-y-3">
              <div className="w-9 h-9 rounded-xl bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center justify-center">
                <ShieldCheck className="w-5 h-5" />
              </div>
              <div>
                <h4 className="text-base font-bold text-white">FSMS Foundation Ready</h4>
                <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                  Design system and common layout initialized with green enterprise styling. Ready for data models and module implementations.
                </p>
              </div>
              <div className="pt-2 flex items-center gap-2">
                <Badge variant="success" size="sm" className="bg-emerald-500/20 border-emerald-500/30 text-emerald-300">
                  Step 1 Complete
                </Badge>
                <span className="text-xs text-slate-400">Frontend Foundation</span>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
