import React from 'react'
import { BrowserRouter } from 'react-router-dom'
import { AppRoutes } from './routes/AppRoutes'
import { EmployeeProvider } from './context/EmployeeContext'

export function App() {
  return (
    <BrowserRouter>
      <EmployeeProvider>
        <AppRoutes />
      </EmployeeProvider>
    </BrowserRouter>
  )
}

export default App
