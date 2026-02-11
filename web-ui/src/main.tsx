import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import HomePage from './pages/HomePage';
import CreatePage from './pages/CreatePage';
import AssetsPage from './pages/AssetsPage';
import StatusPage from './pages/StatusPage';
import SettingsPage from './pages/SettingsPage';
import PipelineEditor from './pages/PipelineEditor';
import EpisodeEditor from './pages/EpisodeEditor';
import EpisodeGenerator from './pages/EpisodeGenerator';
import './styles/theme.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<HomePage />} />
          <Route path="create" element={<CreatePage />} />
          <Route path="assets" element={<AssetsPage />} />
          <Route path="status" element={<StatusPage />} />
          <Route path="pipelines" element={<PipelineEditor />} />
          <Route path="pipelines/:id" element={<PipelineEditor />} />
          <Route path="episodes" element={<EpisodeEditor />} />
          <Route path="episodes/:id" element={<EpisodeGenerator />} />
          <Route path="settings" element={<SettingsPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  </React.StrictMode>,
);
