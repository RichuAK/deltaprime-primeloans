<template>
<div class="rtkn-stats-bar-component">
  <div class="rtkn__title">rTKN conversion program</div>
  <div class="stats-row">
    <div class="stat__entry">
      <div class="stat-label">
        Total rTKN Cap
        <InfoIcon class="info__icon"
                  :tooltip="{content: 'The total dollar value of all positions that are eligible for incentives.', classes: 'info-tooltip'}"
                  :classes="'info-tooltip'">
        </InfoIcon>
      </div>
      <div class="stat-value">{{ maxCap }} rTKN</div>
    </div>
    <div class="stat__entry">
      <div class="stat-label" v-if="maxCap && totalPledged">
        Progress
        <InfoIcon class="info__icon"
                  :tooltip="{content: 'How close we are to completing the next protocol mission.', classes: 'info-tooltip'}"
                  :classes="'info-tooltip'">
        </InfoIcon>
      </div>
      <div class="stat-value">
        <bar-gauge-beta v-tooltip="{content: `Progress ${totalPledged} / ${maxCap} rTKN`, classes: 'info-tooltip'}"
                        :min="0" :max="maxCap" :value="totalPledged" :width="108" :green-on-completion="true"></bar-gauge-beta>
      </div>
    </div>
    <div class="stat__entry">
      <div class="stat-label">
        Total participants
        <InfoIcon class="info__icon"
                  :tooltip="{content: 'The dollar value you receive ARB emissions over. This is calculated as: Total LP/Farms deposits - Collateral value.', classes: 'info-tooltip'}"
                  :classes="'info-tooltip'">
        </InfoIcon>
      </div>
      <div class="stat-value">{{ totalUsers }}</div>
    </div>
    <div class="stat__entry">
      <div class="stat-label">
        rTKNs committed
        <InfoIcon class="info__icon"
                  :tooltip="{content: 'The APR you receive over your eligible TVL.', classes: 'info-tooltip'}"
                  :classes="'info-tooltip'">
        </InfoIcon>
      </div>
      <div class="stat-value">
        {{ yourPledge }} rTKN
      </div>
    </div>
    <div class="stat__entry">
      <div class="stat-label">
        Eligible PRIME
        <InfoIcon class="info__icon"
                  :tooltip="{content: 'The boost APR received if you would borrow enough to get health to 10%, and put your total value into LP/Farms.', classes: 'info-tooltip'}"
                  :classes="'info-tooltip'">
        </InfoIcon>
      </div>
      <div class="stat-value">
        {{ eligiblePrime }}
      </div>
    </div>
    <div class="stat__entry">
      <Button :label="'Convert'" :variant="'slim'" v-on:click="openPledgeModal()"></Button>
    </div>
  </div>
</div>
</template>

<script>


import BarGaugeBeta from './BarGaugeBeta.vue';
import InfoIcon from './InfoIcon.vue';
import config from "../config";
import Button from './Button.vue';
import erc20ABI from '../../test/abis/ERC20.json';
import RtknPledgeModal from './RtknPledgeModal.vue';
import {mapState} from 'vuex';
const ethers = require('ethers');


export default {
  name: 'RTKNStatsBar',
  components: {Button, InfoIcon, BarGaugeBeta},
  data() {
    return {
    }
  },
  props: {
    maxCap: {},
    totalPledged: {},
    totalUsers: {},
    yourPledge: {},
    eligiblePrime: {},
    available: {},
    conversionRatio: {},
  },
  mounted() {
  },
  computed: {
    ...mapState('serviceRegistry', ['accountService', 'rtknService']),
  },
  methods: {
    async openPledgeModal() {
      console.log('test');
      const modalInstance = this.openModal(RtknPledgeModal);
      modalInstance.available = this.available;
      modalInstance.yourPledge = this.yourPledge;
      modalInstance.rtknCap = this.maxCap;
      modalInstance.totalPledge = this.totalPledged;
      modalInstance.conversionRatio = this.conversionRatio;
      modalInstance.totalUsers = this.totalUsers;

      modalInstance.$on('PLEDGE', (pledgeEvent) => {
        this.rtknService.pledge(pledgeEvent.value);
      });
    },
  },
};
</script>

<style lang="scss" scoped>
@import "~@/styles/variables";

.rtkn-stats-bar-component {
  display: flex;
  flex-direction: column;
  height: 130px;
  margin-top: 30px;
  margin-bottom: 30px;
  padding: 0 53px;
  border-radius: 35px;
  background-color: var(--rtkn-stats-bar__background);
  box-shadow: 7px 7px 30px 0 #{$dark-space}66;

  .rtkn__title {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: center;
    width: 100%;
    color: var(--rtkn-stats-bar-text__color);
    font-size: $font-size-sm;
    font-weight: 600;
    padding: 6px 0;
    border-style: solid;
    border-width: 0 0 2px 0;
    border-image-source: var(--asset-table-row__border);
    border-image-slice: 1;
  }

  .stats-row {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    padding: 22px 0 27px 0;
    margin: 0 -40px;

    .stat__entry {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      font-size: $font-size-xsm;
      font-weight: 500;
      color: var(--rtkn-stats-bar-text__color);
      width: 100%;

      .stat-label {
        display: flex;
        flex-direction: row;
        align-items: center;
        font-size: $font-size-xsm;
        font-weight: 500;
        color: var(--rtkn-stats-bar-text__color);
        margin-bottom: 12px;

        .info__icon {
          margin-left: 5px;
        }
      }

      .stat-value {
        display: flex;
        flex-direction: row;
        align-items: center;
        font-size: $font-size-xsm;
        font-weight: 600;
        color: var(--rtkn-stats-bar-value__color);

        .incentives-icon {
          width: 16px;
          height: 16px;
          margin-left: 5px;
        }

        .shine-icon {
          width: 20px;
          height: 20px;
          margin-left: 5px;
          background-image: var(--rtkn-stats-bar-value-icon);
        }
        .speed-bonus {
          opacity: 50%;

          &.speed-bonus-active {
            opacity: 100%;
            color: var(--colored-value-beta__color--positive);
          }
        }
      }
    }
  }
}

</style>
