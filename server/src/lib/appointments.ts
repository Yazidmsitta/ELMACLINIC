import { z } from 'zod';
import { databaseError } from './catalog';
import { HttpError } from './http';
export const appointmentStatus = z.enum(['NEW','PENDING','CONFIRMED','IN_PROGRESS','COMPLETED','CANCELLED','NO_SHOW']);
export const bookingSelection = z.object({
  client_id: z.uuid(), practitioner_id: z.uuid(),
  service_ids: z.array(z.uuid()).max(10).refine(ids => new Set(ids).size===ids.length),
  pack_ids: z.array(z.uuid()).max(10).default([]).refine(ids => new Set(ids).size===ids.length),
  starts_at: z.iso.datetime({offset:true}),
}).strict().refine(
  selection => selection.service_ids.length > 0 || selection.pack_ids.length > 0,
  { message: 'Sélectionnez au moins une prestation ou un pack.', path: ['service_ids'] },
);
export const bookingCreate = bookingSelection.extend({
  notes:z.string().trim().max(2000).nullable().optional(), request_id:z.uuid(),
  expected_total_centimes:z.number().int().min(0).max(1000000000), expected_duration_minutes:z.number().int().min(1).max(1440),
}).strict();
export function appointmentError(error: {code?:string;message?:string}|null): void {
  if (!error) return;
  const messages = ['Praticienne inactive ou introuvable.','Le rendez-vous doit être compris dans un créneau de travail.',
    'La praticienne est absente sur ce créneau.','Ce créneau est déjà réservé.','Sélection de prestations invalide.','Client introuvable.',
    'Choisissez un créneau futur.','Clé de requête déjà utilisée.','Le rendez-vous a été modifié. Actualisez la fiche.',
    'Ce rendez-vous ne peut plus être déplacé.','Transition de statut interdite.','Ce rendez-vous n’a pas encore commencé.',
    'Le tarif ou la durée a changé. Vérifiez le nouveau devis.','Le total ne peut pas être inférieur aux paiements déjà encaissés.'];
  if (messages.includes(error.message ?? '')) throw new HttpError(error.code==='22023' ? 422 : 409,error.message!);
  databaseError(error);
}
