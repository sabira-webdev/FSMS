import React from 'react'
import { User, ShieldCheck, Mail, Building, Award, Edit3 } from 'lucide-react'
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

export function Profile() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="My Profile"
        subtitle="Manage your personal credentials, digital signature, and auditor certifications."
        badge={<Badge variant="success" dot size="sm">Verified Lead Auditor</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'My Profile' }]}
        actions={
          <Button variant="primary" size="sm" icon={Edit3}>
            Edit Profile
          </Button>
        }
      />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column: Avatar & summary card */}
        <Card className="text-center p-6 space-y-4">
          <div className="w-20 h-20 rounded-2xl bg-gradient-to-tr from-emerald-700 to-teal-500 text-white font-bold text-2xl flex items-center justify-center mx-auto shadow-md shadow-emerald-900/20">
            SJ
          </div>
          <div>
            <h3 className="text-lg font-bold text-slate-900">Dr. Sarah Jenkins</h3>
            <p className="text-xs text-slate-500 font-medium">Head of Quality Assurance & Compliance</p>
            <div className="mt-2 flex items-center justify-center gap-1.5">
              <Badge variant="success" size="sm">Active</Badge>
              <Badge variant="neutral" size="sm">ID: QA-8841</Badge>
            </div>
          </div>
          <div className="pt-4 border-t border-slate-100 text-xs text-left space-y-2.5 text-slate-600">
            <div className="flex items-center gap-2">
              <Mail className="w-4 h-4 text-slate-400" />
              <span>s.jenkins@fsms-enterprise.org</span>
            </div>
            <div className="flex items-center gap-2">
              <Building className="w-4 h-4 text-slate-400" />
              <span>Plant 1 - Central Quality Directorate</span>
            </div>
            <div className="flex items-center gap-2">
              <Award className="w-4 h-4 text-emerald-600" />
              <span>ISO 22000 & BRCGS Lead Auditor</span>
            </div>
          </div>
        </Card>

        {/* Right 2 Columns: Credentials and certifications */}
        <div className="lg:col-span-2 space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Certifications & Qualifications</CardTitle>
              <CardDescription>Verified food safety credentials authorized for signing off audits.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-emerald-50 text-emerald-700">
                    <ShieldCheck className="w-5 h-5" />
                  </div>
                  <div>
                    <h5 className="text-xs font-bold text-slate-800">ISO 22000:2018 Lead Auditor</h5>
                    <p className="text-[11px] text-slate-500">Certified by IRCA • Valid until Dec 2027</p>
                  </div>
                </div>
                <Badge variant="success" size="sm">Verified</Badge>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-blue-50 text-blue-700">
                    <ShieldCheck className="w-5 h-5" />
                  </div>
                  <div>
                    <h5 className="text-xs font-bold text-slate-800">HACCP Level 4 Management</h5>
                    <p className="text-[11px] text-slate-500">Royal Society for Public Health • Valid</p>
                  </div>
                </div>
                <Badge variant="success" size="sm">Verified</Badge>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
