## Surreal World Assets Buildathon
```
oa0u02vokr732otohv3onoa0u0n4nqzn
```

# Makgora

> **The on‑chain, high‑stakes IP brawler where every victory mints history—and every defeat is permanent.**

---

## Overview

**Makgora** is a fast‑paced PvP arena in which every combatant is an NFT that embodies user‑generated intellectual property (IP). Players either mint a fighter **from scratch** or **remix** an existing fighter’s lore, then throw them into AI‑refereed battles. Winners climb an endless win‑streak ladder and siphon most of the game’s revenue; losers are burned forever. Every action—minting, battling, licensing, and payout—executes transparently on‑chain.

### Key Features

* **Permadeath Stakes** – Lose a battle and your NFT is permanently burned.
* **Dynamic IP Economy** – Scratch fighters cost a flat fee; Remix fighters get pricier every 10 mints and pay lifetime royalties to their parent IP.
* **Alpha Throne** – The fighter with the longest active win streak (the *Alpha*) receives 90 % of all mint income until dethroned.
* **AI‑Powered Oracles** – Large‑language‑model (LLM) services generate remixed lore and adjudicate battles in 2–3 lines of narrative.
* **Full Automation via Gelato** – Off‑chain tasks listen for on‑chain events, call the LLM backend, and push signed transactions—all without human intervention.

---

## Gameplay Loop

### 1. Create a Fighter

| Mode        | Base Cost      | Description                                                                                        |
| ----------- | -------------- | -------------------------------------------------------------------------------------------------- |
| **Scratch** | **0.1 ETH**    | Provide a name + description and mint a brand‑new IP.                                              |
| **Remix**   | **≥ 0.2 ETH**¹ | Add your own twist to an existing fighter. 50 % of its future earnings flow back to the parent IP. |

¹ Remix price doubles *every* 10 remixes of the same parent.

*All descriptions are AES‑GCM encrypted on‑chain; only the backend decrypts them for LLM processing.*

### 2. Enter the Arena

1. Click **Battle** to join the first‑come‑first‑served queue.
2. When matched, the LLM produces a 2–3 line battle log and selects a winner.
3. **Loser:** NFT is burned.
4. **Winner:** +1 win streak. If you now hold the longest active streak you become **Alpha**.
5. **Inactivity Penalty:** Each hour without entering a new battle subtracts 1 win streak.

### 3. Revenues & Fees

| Flow           | Recipient      | Amount                  |
| -------------- | -------------- | ----------------------- |
| Scratch Mint   | Alpha          | 0.09 ETH                |
|                | Service Fee    | 0.01 ETH                |
| Remix Mint     | Alpha          | 0.09 ETH                |
|                | Service Fee    | 0.01 ETH                |
|                | Parent IP      | *Remix Price* − 0.1 ETH |
| Remix Earnings | Parent IP      | 50 %                    |
|                | Child IP Owner | 50 %                    |

*(The system fee is always 10 % of any transaction.)*

---

## Architecture

| Layer                   | Role                                                                                            |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| **Smart Contracts**     | NFT storage, battle results, revenue routing.                                                   |
| **Backend LLM Service** | **Remix API** (generates new lore), **Battle API** (decides winner & log).                      |
| **Gelato Autotasks**    | Listens for *RemixRequested* / *BattleRequested* events, calls backend, submits signed results. |
| **Encryption Layer**    | Encrypts/decrypts fighter lore; keys never leave backend.                                       |

---

## Getting Started

1. **Connect** your EVM‑compatible wallet.
2. **Mint** a fighter via Scratch or Remix.
3. Hit **Battle** and climb the ladder.
4. **Adapt or perish.** Losing means permanent death—so be ready to mint again.

---
