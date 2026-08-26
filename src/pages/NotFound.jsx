import React from 'react'
import { Link } from 'react-router-dom'
import { AlertCircle, ArrowLeft } from 'lucide-react'
import { Button, Card } from '../components/common'

export function NotFound() {
  return (
    <div className="py-16 flex items-center justify-center">
      <Card className="p-8 max-w-md w-full text-center space-y-4 shadow-lg">
        <div className="w-14 h-14 rounded-2xl bg-amber-50 text-amber-600 flex items-center justify-center mx-auto border border-amber-100">
          <AlertCircle className="w-7 h-7" />
        </div>
        <div>
          <h2 className="text-2xl font-bold text-slate-900">Page Not Found</h2>
          <p className="text-xs text-slate-500 mt-1">
            The food safety module or record you requested does not exist or has been relocated.
          </p>
        </div>
        <div className="pt-2">
          <Link to="/">
            <Button variant="primary" size="sm" icon={ArrowLeft}>
              Return to Dashboard
            </Button>
          </Link>
        </div>
      </Card>
    </div>
  )
}
