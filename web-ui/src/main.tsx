import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import HomePage from './pages/HomePage';
import CreateVideoPage from './pages/CreateVideoPage';
import CreateImagePage from './pages/CreateImagePage';
import AssetsPage from './pages/AssetsPage';
import StatusPage from './pages/StatusPage';
import SettingsPage from './pages/SettingsPage';
import PipelineEditor from './pages/PipelineEditor';
import './styles/theme.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<HomePage />} />
          <Route path="create/video" element={<CreateVideoPage />} />
          <Route path="create/image" element={<CreateImagePage />} />
          <Route path="assets" element={<AssetsPage />} />
          <Route path="status" element={<StatusPage />} />
          <Route path="pipelines" element={<PipelineEditor />} />
          <Route path="pipelines/:id" element={<PipelineEditor />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  </React.StrictMode>,
);
