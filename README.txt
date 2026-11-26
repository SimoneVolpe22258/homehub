HOME HUB 0.4.3 – Family & Challenge
Eseguire upgrade_v0.4.3.sql dopo le migrazioni precedenti. Genitore = admin; gli adulti precedentemente autorizzati al concorso devono ricevere un invito Genitore per mantenere i privilegi. Inviti legati a email verificata, validi 48 ore. Proposte premio accolte non costituiscono un premio assegnato. Iniziative accolte passano alla verifica finale. Offline sola lettura. Test di integrazione Supabase da eseguire.

v0.5.0 Family Station: eseguire upgrade_v0.5.0.sql dopo v0.4.3. Pubblicare anche station.html e station.js. Da account admin, Famiglia > Family Station > Associa tablet. Aprire il link generato esclusivamente sul tablet (non condividere pubblicamente). Il link è una credenziale revocabile. Selezionare un profilo; blocco dopo 180 secondi. Il tablet richiede connessione e non consente operazioni amministrative. Non usare un account personale sul tablet. Per dissociare, revocare da account admin e cancellare dati sito sul tablet. La selezione senza password non prova l'identità della persona. Test live Supabase non eseguiti.

0.5.1: eseguire upgrade_v0.5.1.sql dopo 0.5.0. Missioni libere con presa in carico atomica e rinuncia. Scadenza missione usata anche per presa in carico. Ricorrenze non implementate.

0.5.2: eseguire upgrade_v0.5.2.sql. Solo admin possono eliminare attività domestiche e annullare missioni. Le missioni annullate restano nello storico, escluse dai punti; premi già consegnati non vengono recuperati automaticamente. Test live necessari.

v0.5.3: applicare upgrade_v0.5.3.sql dopo v0.5.2. Storico, rettifiche punti e premi a soglia. Le date storiche non registrate restano sconosciute. Tablet: solo filtro attività operative; punteggi manuali e premi non integrati nella Station. Verifica SQL su Supabase e test browser necessari.
