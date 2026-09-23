using ChainsawManMod.Common.Systems;
using ChainsawManMod.Content.Items;
using ChainsawManMod.Content.Projectiles;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.Audio;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Post-Moon Lord boss. Makima walks calmly toward the player and cycles through:
	//   Bang         - points at the player and fires crushing shots
	//   Hounds       - white dogs burst out of the ground under the player after a short warning
	//   Gun Fiends   - summons floating gun fiends that spray bullets
	//   Contract     - calls other devils to fight for her; she takes half damage while any of them live
	//   Teleport     - melts into blood and reappears next to the player
	// At half health she is knocked down, gets back up, and everything becomes faster and stronger.
	[AutoloadBossHead]
	public class Makima : ModNPC
	{
		// Frame ranges in Makima.png (see tools/clean_sprite_sheet.py).
		private const int IdleStart = 0, IdleCount = 5;
		private const int WalkStart = 5, WalkCount = 6;
		private const int BangStart = 11, BangCount = 7;
		private const int SummonStart = 18, SummonCount = 5;
		private const int DissolveStart = 23, DissolveCount = 8;
		private const int KnockdownStart = 31, KnockdownCount = 7;
		private const int TotalFrames = 38;

		private const int StateWalk = 0;
		private const int StateBang = 1;
		private const int StateHounds = 2;
		private const int StateGunFiends = 3;
		private const int StateContract = 4;
		private const int StateTeleportOut = 5;
		private const int StateTeleportIn = 6;
		private const int StateKnockdown = 7;

		private const int MaxContractDevils = 6;

		private ref float State => ref NPC.ai[0];
		private ref float Timer => ref NPC.ai[1];
		private ref float NextAttack => ref NPC.ai[2];
		private bool PhaseTwo {
			get => NPC.ai[3] == 1f;
			set => NPC.ai[3] = value ? 1f : 0f;
		}

		// Devils Makima can call with her Contract attack.
		private static int[] ContractDevils => new[] {
			ModContent.NPCType<ZombieDevilMinion>(),
			ModContent.NPCType<DevilBat>(),
			ModContent.NPCType<GhostDevil>(),
			ModContent.NPCType<FireDevil>(),
			ModContent.NPCType<GunDevilSpawn>()
		};

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = TotalFrames;
			NPCID.Sets.MPAllowedEnemies[Type] = true;
			NPCID.Sets.BossBestiaryPriority.Add(Type);
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Poisoned] = true;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Confused] = true;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.OnFire] = true;
		}

		public override void SetDefaults() {
			NPC.width = 30;
			NPC.height = 60;
			NPC.damage = 120;
			NPC.defense = 60;
			NPC.lifeMax = 150000;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath6;
			NPC.knockBackResist = 0f;
			NPC.value = Item.buyPrice(platinum: 1);
			NPC.SpawnWithHigherTime(30);
			NPC.boss = true;
			NPC.npcSlots = 15f;
			NPC.aiStyle = -1;

			if (!Main.dedServ) {
				Music = MusicID.OtherworldlyBoss1;
			}
		}

		public override void AI() {
			if (NPC.target < 0 || NPC.target == 255 || Main.player[NPC.target].dead || !Main.player[NPC.target].active) {
				NPC.TargetClosest();
			}
			Player player = Main.player[NPC.target];

			if (player.dead) {
				// Nobody left to control: melt away.
				NPC.velocity.X = 0f;
				NPC.alpha = System.Math.Min(255, NPC.alpha + 5);
				NPC.EncourageDespawn(10);
				return;
			}

			NPC.direction = player.Center.X > NPC.Center.X ? 1 : -1;
			NPC.spriteDirection = -NPC.direction; // the sprites face right; Terraria expects left-facing NPC art
			NPC.dontTakeDamage = State == StateTeleportOut || State == StateTeleportIn || State == StateKnockdown;
			Timer++;

			// Knocked down once at half health, then phase two.
			if (!PhaseTwo && State != StateKnockdown && NPC.life < NPC.lifeMax / 2) {
				SetState(StateKnockdown);
			}

			// Too far away: teleport to the player.
			if (Vector2.Distance(NPC.Center, player.Center) > 1400f && State == StateWalk) {
				SetState(StateTeleportOut);
			}

			switch ((int)State) {
				case StateWalk:
					Walk(player);
					break;
				case StateBang:
					Bang(player);
					break;
				case StateHounds:
					Hounds(player);
					break;
				case StateGunFiends:
					GunFiends(player);
					break;
				case StateContract:
					Contract();
					break;
				case StateTeleportOut:
					TeleportOut(player);
					break;
				case StateTeleportIn:
					TeleportIn();
					break;
				case StateKnockdown:
					Knockdown();
					break;
			}
		}

		private void Walk(Player player) {
			float speed = PhaseTwo ? 3.2f : 2.2f;
			NPC.velocity.X = MathHelper.Lerp(NPC.velocity.X, NPC.direction * speed, 0.1f);
			if (NPC.velocity.Y == 0f && (NPC.collideX || player.Bottom.Y < NPC.Top.Y - 64f)) {
				NPC.velocity.Y = -9f; // hop over walls and up to the player
			}

			if (Timer >= (PhaseTwo ? 70 : 110)) {
				// Cycle through the attacks in order.
				int[] order = { StateBang, StateHounds, StateGunFiends, StateBang, StateContract, StateTeleportOut };
				SetState(order[(int)NextAttack % order.Length]);
				NextAttack++;
			}
		}

		private void Bang(Player player) {
			NPC.velocity.X *= 0.8f;

			// Fire on the 4th frame of the pointing animation; twice (three times in phase two) in a row.
			int shots = PhaseTwo ? 3 : 2;
			if (Timer % 30 == 18 && Timer < 30 * shots) {
				Vector2 hand = NPC.Center + new Vector2(NPC.direction * 20f, -10f);
				Vector2 aim = (player.Center - hand).SafeNormalize(Vector2.UnitX * NPC.direction);
				DevilUtils.Shoot(NPC, hand, aim * 22f, ModContent.ProjectileType<DevilBullet>(), NPC.damage / 3);
				SoundEngine.PlaySound(SoundID.Item11, hand);
				for (int i = 0; i < 12; i++) {
					Dust.NewDust(hand, 4, 4, DustID.Smoke, aim.X * 3f, aim.Y * 3f);
				}
			}

			if (Timer >= 30 * shots + 10) {
				SetState(StateWalk);
			}
		}

		private void Hounds(Player player) {
			NPC.velocity.X *= 0.8f;

			if (Timer == 20) {
				SoundEngine.PlaySound(SoundID.Roar, NPC.Center);
				int count = PhaseTwo ? 5 : 3;
				for (int i = 0; i < count; i++) {
					float offset = (i - (count - 1) / 2f) * 90f;
					// Projectiles spawn centred on the point, so lift it by half the hound's height to sit on the ground.
					Vector2 spot = player.Bottom + new Vector2(offset + player.velocity.X * 20f, -35f);
					DevilUtils.Shoot(NPC, spot, Vector2.Zero, ModContent.ProjectileType<MakimaHound>(), NPC.damage / 3);
				}
			}

			if (Timer >= 60) {
				SetState(StateWalk);
			}
		}

		private void GunFiends(Player player) {
			NPC.velocity.X *= 0.8f;

			if (Timer == 20) {
				int count = PhaseTwo ? 3 : 2;
				for (int i = 0; i < count; i++) {
					Vector2 spot = NPC.Center + new Vector2(-NPC.direction * 60f, -90f - i * 70f);
					DevilUtils.Shoot(NPC, spot, Vector2.Zero, ModContent.ProjectileType<MakimaGunFiend>(), NPC.damage / 3, ai0: NPC.target);
				}
			}

			if (Timer >= 50) {
				SetState(StateWalk);
			}
		}

		private void Contract() {
			NPC.velocity.X *= 0.8f;

			if (Timer == 20 && DevilUtils.CountActiveAny(ContractDevils) < MaxContractDevils) {
				int count = PhaseTwo ? 3 : 2;
				for (int i = 0; i < count; i++) {
					int type = ContractDevils[Main.rand.Next(ContractDevils.Length)];
					DevilUtils.SpawnMinion(NPC, type, NPC.Center + new Vector2(Main.rand.NextFloat(-120f, 120f), -80f));
				}
				for (int i = 0; i < 30; i++) {
					Dust.NewDust(NPC.position, NPC.width, NPC.height, DustID.Blood, 0f, -3f);
				}
			}

			if (Timer >= 50) {
				SetState(StateWalk);
			}
		}

		private void TeleportOut(Player player) {
			NPC.velocity.X = 0f;
			if (Timer >= 40) {
				if (Main.netMode != NetmodeID.MultiplayerClient) {
					float side = Main.rand.NextBool() ? 1f : -1f;
					NPC.Bottom = player.Bottom + new Vector2(side * 220f, 0f);
					NPC.velocity = Vector2.Zero;
				}
				SetState(StateTeleportIn);
			}
		}

		private void TeleportIn() {
			NPC.velocity.X = 0f;
			if (Timer >= 40) {
				SetState(StateWalk);
			}
		}

		private void Knockdown() {
			NPC.velocity.X *= 0.9f;
			if (Timer == 1) {
				SoundEngine.PlaySound(SoundID.NPCDeath6, NPC.Center);
			}
			if (Timer >= 150) {
				PhaseTwo = true;
				SoundEngine.PlaySound(SoundID.Roar, NPC.Center);
				SetState(StateWalk);
			}
		}

		private void SetState(int state) {
			State = state;
			Timer = 0f;
			NPC.netUpdate = true;
		}

		// "Damage is redirected to her contracts": half damage while any of her devils are alive.
		public override void ModifyIncomingHit(ref NPC.HitModifiers modifiers) {
			if (DevilUtils.CountActiveAny(ContractDevils) > 0) {
				modifiers.FinalDamage *= 0.5f;
			}
		}

		public override void FindFrame(int frameHeight) {
			int frame;
			switch ((int)State) {
				case StateBang:
					frame = BangStart + System.Math.Min(BangCount - 1, (int)(Timer % 30) / 4);
					break;
				case StateHounds:
				case StateContract:
					frame = SummonStart + System.Math.Min(SummonCount - 1, (int)Timer / 5);
					break;
				case StateGunFiends:
					frame = BangStart + System.Math.Min(3, (int)Timer / 5); // point, then hold
					break;
				case StateTeleportOut:
					frame = DissolveStart + System.Math.Min(DissolveCount - 1, (int)Timer / 5);
					break;
				case StateTeleportIn:
					frame = DissolveStart + DissolveCount - 1 - System.Math.Min(DissolveCount - 1, (int)Timer / 5);
					break;
				case StateKnockdown:
					// Fall over, lie there, then sit up.
					int k = Timer < 20 ? (int)Timer / 7 : Timer < 120 ? 3 + ((int)Timer / 20) % 3 : KnockdownCount - 1;
					frame = KnockdownStart + System.Math.Min(KnockdownCount - 1, k);
					break;
				default:
					if (System.Math.Abs(NPC.velocity.X) > 0.3f) {
						NPC.frameCounter++;
						frame = WalkStart + (int)(NPC.frameCounter / 7) % WalkCount;
					}
					else {
						NPC.frameCounter++;
						frame = IdleStart + (int)(NPC.frameCounter / 10) % IdleCount;
					}
					break;
			}
			NPC.frame.Y = frame * frameHeight;
		}

		public override bool CanHitPlayer(Player target, ref int cooldownSlot) {
			cooldownSlot = ImmunityCooldownID.Bosses;
			return State != StateTeleportOut && State != StateTeleportIn && State != StateKnockdown;
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<HeroOfHellsCord>(), 3));
			npcLoot.Add(ItemDropRule.Common(ItemID.LunarBar, 1, 20, 30));
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 40, 60));
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<GunDevilFragment>(), 1, 20, 30));
		}

		public override void BossLoot(ref int potionType) {
			potionType = ItemID.SuperHealingPotion;
		}

		public override void OnKill() {
			NPC.SetEventFlagCleared(ref DownedDevilSystem.downedMakima, -1);
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new MoonLordPortraitBackgroundProviderBestiaryInfoElement(),
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.Makima")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
